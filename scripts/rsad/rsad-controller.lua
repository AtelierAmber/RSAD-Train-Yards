require("scripts.rsad.train-yard")
require("scripts.rsad.station")
scheduler = require("scripts.rsad.scheduler")
require("scripts.util.events")

ticks_per_update = math.floor(360/settings.startup["rsad-station-update-rate"].value) + 1

---@type string?
active_yard = nil

local next = next -- Assign local table next for indexing speed

---@class rsad_controller
rsad_controller = {
    stations = nil, --[[@type table<uint, RSADStation>]]
    train_yards = nil, --[[@type table<string, TrainYard>]]
    scheduler = scheduler --[[@type scheduler]]
}

---@param self rsad_controller
function rsad_controller.__init(self)
    storage.stations = {} --[[@type table<uint, RSADStation>]]
    --storage.shunter_trains = {} --[[@type table<string, table<uint, ShuntingData>>}]]
    storage.train_yards = {} --[[@type table<string, TrainYard>]]
    self.stations = storage.stations
    self.train_yards = storage.train_yards
end

---@param self rsad_controller
function rsad_controller.__load(self)
    --- Create train yards
    self.stations = storage.stations
    self.train_yards = storage.train_yards
end

---@param self rsad_controller
---@param tick_data NthTickEventData
function rsad_controller.__tick(self, tick_data)
    --- Check first if any shunting orders need to be issued
    if self.scheduler:tick(self) then end

    ---@type TrainYard?
    local yard
    ---@type string?
    local k
    while active_yard ~= nil do
        yard = self.train_yards[active_yard]
        if yard then
            if yard:tick(self) then break end
        end
        ---@diagnostic disable-next-line: unbalanced-assignments
        k, yard = next(self.train_yards, active_yard)
        active_yard = k
    end
    if not active_yard then active_yard = next(self.train_yards, active_yard) end
end

---@param self rsad_controller
---@param train LuaTrain
---@param old_state defines.train_state
function rsad_controller.__on_train_state_change(self, train, old_state)
    if train.state == defines.train_state.wait_station then
        self:assign_shunter(train) --Includes a check to make sure it's arrived at a shunting_depot
    end
    self.scheduler:manage_train_state_change(train, old_state)
end

---@param self rsad_controller
---@param entity LuaEntity
---@return boolean
function rsad_controller.__on_station_destroyed(self, entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return true end

    local station = self.stations[entity.unit_number]
    if not station then return true end

    self:decommision_station_from_yard(station, true)
    --game.print(serpent.block(self.stations))
    return true
end

---@param self rsad_controller
---@param entity LuaEntity
---@return boolean
function rsad_controller.__on_station_built(self, entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return true end

    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local network = control.stopped_train_signal --[[@as SignalID?]]
    if network then
        local found, station = self:get_or_create_station(entity, network)
        if found and station then
            self:migrate_station(station, network)
        end
    end

    return true
end

---@param entity LuaEntity
function rsad_controller.__on_paste_settings(self, entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return end
    
    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local network = control.stopped_train_signal --[[@as SignalID?]]
    if network then
        local found, station = self:get_or_create_station(entity, network)
        if found and station then
            self:migrate_station(station, network)
        end
    end
end

---@param self rsad_controller
function rsad_controller.register_events(self)
   events.register_init(function() self:__init() end)
   events.register_load(function() self:__load() end)
   events.register_break("name", names.entities.rsad_station, function(entity) return self:__on_station_destroyed(entity) end)
   events.register_build("name", names.entities.rsad_station, function(entity) return self:__on_station_built(entity) end)
   events.register_paste(function(entity) self:__on_paste_settings(entity) end )
   events.register_train_handler(defines.events.on_train_changed_state, function(data) self:__on_train_state_change(data.train, data.old_state) end)
   script.on_nth_tick(ticks_per_update, function(tick_data) self:__tick(tick_data) end)
   script.on_event(defines.events.on_player_created, function(data) self:__load() end)
end

---@param self rsad_controller
---@param signal SignalID
---@return TrainYard?
function rsad_controller.get_train_yard_or_nil(self, signal)
    local hash = signal_hash(signal)
    return hash and self.train_yards[hash]
end

---Get or creates a train yard with specified signal
---@param self rsad_controller
---@param signal SignalID
---@return TrainYard? yard
function rsad_controller.get_or_create_train_yard(self, signal)
    local hash = signal_hash(signal)
    if not hash then return nil end
    self.train_yards[hash] = self.train_yards[hash] or create_train_yard(signal)
    return self.train_yards[hash]
end

---Returns false if needed to create, true if it was found
---@param self rsad_controller
---@param entity LuaEntity
---@param network SignalID?
---@return boolean, RSADStation? 
function rsad_controller.get_or_create_station(self, entity, network)
    local unit_number = entity.unit_number
    
    local station = self.stations[unit_number] --[[@as RSADStation?]]
    if not station and network then
        station = self:construct_station(entity, network)
        return false, station
    end
    return true, station
end

--- Creates station and assignes it to a train yard
---@param self rsad_controller
---@param entity LuaEntity
---@param network SignalID
---@return RSADStation?
function rsad_controller.construct_station(self, entity, network)
    local yard = self:get_or_create_train_yard(network)
    if not yard then
        return nil
    end

    local station = create_rsad_station(entity)
    if not station then
        return nil
    end

    self.stations[entity.unit_number] = station
    yard:add_or_update_station(station)
    return station
end

---comment
---@param self rsad_controller
---@param station RSADStation
---@param keep_network boolean? --If true, it will keep the network assigned in the station. Used only for destroying
function rsad_controller.decommision_station_from_yard(self, station, keep_network)
    if not station then return end
    local success, entity, data = get_station_data(station)
    if not success or not data then
        self.stations[station.unit_number] = nil
        return
    end

    local hash = signal_hash(data.network)
    if hash then
        local yard = data.network and self.train_yards[hash] --[[@as TrainYard?]]
        if yard then
            yard:remove_station(station)
            if yard:is_empty() then
                self.train_yards[hash] = nil
            end
        end
    end

    if not keep_network then
        decommision_station(station)
    end
    self.stations[station.unit_number] = nil
end

---comment
---am self rsad_controller
---@param station RSADStation
---@param new_network SignalID
---@return boolean
function rsad_controller.migrate_station(self, station, new_network)
    local new_yard = self:get_or_create_train_yard(new_network)
    if not new_yard then return false end
    
    self:decommision_station_from_yard(station)
    return new_yard:add_or_update_station(station)
end

---comment
---@param self rsad_controller
---@param train LuaTrain
function rsad_controller.assign_shunter(self, train)
    local rsad_station = self.stations[train.station.unit_number]
    if rsad_station then
        local success, station_entity, data = get_station_data(rsad_station)
        if success and data and data.type == rsad_station_type.shunting_depot then
            local yard = self:get_or_create_train_yard(data.network)
            if yard then
                yard:add_new_shunter(train)
            end
        end
    end
end

return rsad_controller