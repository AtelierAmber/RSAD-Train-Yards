require("scripts.rsad.train-yard")
require("scripts.rsad.station")
scheduler = require("scripts.rsad.scheduler")
require("scripts.util.events")

ticks_per_update = 360/settings.startup["rsad-station-update-rate"] --[[@as int]]

---@type string?
active_yard = nil

local next = next -- Assign local table next for indexing speed

---@class rsad_controller
rsad_controller = {
    stations = {}, --[[@type table<uint, RSADStation>]]
    train_yards = {}, --[[@type table<string, TrainYard>]]
    scheduler = scheduler
}

function rsad_controller.__init(self)
    --storage.stations = {}
    --storage.shunter_trains = {} --[[@type table<string, table<uint, ShuntingData>>}]]
end

function rsad_controller.__load(self)
    if storage.shunter_trains then
        for network, trains in pairs(storage.shunter_trains) do
            
        end
    end
end

function rsad_controller.__tick(self)
    --- Check first if any shunting orders need to be issued
    if self.scheduler:tick() then end
    ---@type TrainYard?
    local yard
    ---@type string?
    local k
---@diagnostic disable-next-line: unbalanced-assignments
    k, yard = next(self.train_yards, active_yard) or next(self.train_yards)
    active_yard = k
    if not active_yard or not yard then return end
    yard:tick()
end

---@param entity LuaEntity
---@return boolean
function rsad_controller.__on_station_destroyed(self, entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return true end

    local station = self.stations[entity.unit_number]
    if not station then return true end

    self:decommision_station_from_yard(station)
    --game.print(serpent.block(self.stations))
    return true
end

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

function rsad_controller.register_events(self)
   events.register_init(function() self:__init() end)
   events.register_load(function() self:__load() end)
   events.register_break("name", names.entities.rsad_station, function(entity) return self:__on_station_destroyed(entity) end)
   events.register_build("name", names.entities.rsad_station, function(entity) return self:__on_station_built(entity) end)
   events.register_paste(function(entity) self:__on_paste_settings(entity) end )
end

---@param signal SignalID
---@return TrainYard?
function rsad_controller.get_train_yard_or_nil(self, signal)
    local hash = signal_hash(signal)
    return hash and self.train_yards[hash]
end

---Get or creates a train yard with specified signal
---@param signal SignalID
---@return TrainYard? yard
function rsad_controller.get_or_create_train_yard(self, signal)
    local hash = signal_hash(signal)
    if not hash then return nil end
    self.train_yards[hash] = self.train_yards[hash] or create_train_yard(signal)
    return self.train_yards[hash]
end

---Returns false if needed to create, true if it was found
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
    update_station_data(station, {network = network})
    yard:add_or_update_station(station)
    return station
end

---comment
---@param station RSADStation
function rsad_controller.decommision_station_from_yard(self, station)
    if not station then return end
    local success, data = get_station_data(station)
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

    decommision_station(station)
    self.stations[station.unit_number] = nil
end

---comment
---@param station RSADStation
---@param new_network SignalID
---@return boolean
function rsad_controller.migrate_station(self, station, new_network)
    local new_yard = self:get_or_create_train_yard(new_network)
    if not new_yard then return false end
    
    self:decommision_station_from_yard(station)
    return new_yard:add_or_update_station(station)
end

return rsad_controller