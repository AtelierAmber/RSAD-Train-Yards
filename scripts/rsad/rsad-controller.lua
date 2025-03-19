require("scripts.rsad.train-yard")
require("scripts.rsad.station")
scheduler = require("scripts.rsad.scheduler")
require("scripts.util.events")

local ticks_per_update = math.floor(360/settings.startup["rsad-station-update-rate"].value) + 1
local max_train_limit = settings.startup["rsad-station-max-train-limit"].value --[[@as integer]]
local max_cargo_limit = settings.startup["rsad-station-max-cargo-limit"].value --[[@as integer]]

---@type string?
active_yard = nil

--#region Function Localization for indexing speed

local next = next
local pairs = pairs

--#endregion

---@class RSAD.Controller
rsad_controller = {
    stations = nil, --[[@type table<uint, RSADStation>]]
    train_yards = nil, --[[@type table<string, TrainYard>]]
    scheduler = scheduler, --[[@type scheduler]]
    shunter_networks = {} --[[@type table<integer, string>]] -- Train ID to TrainYard network hash
}
rsad_controller.scheduler.controller = rsad_controller

---@package
---@param self RSAD.Controller
function rsad_controller.__init(self)
    if not storage.stations then storage.stations = {} end
    self.stations = storage.stations
    if not storage.train_yards then storage.train_yards = {} end
    self.train_yards = storage.train_yards or {}
    for network, yard in pairs(storage.train_yards) do
        for id, info in pairs(yard.shunter_trains) do
            self.shunter_networks[id] = network
        end
    end
    storage.needs_tick = storage.needs_tick or false
    if not storage.scripted_trains then storage.scripted_trains = {} end
    self.scheduler.scripted_trains = storage.scripted_trains or {}
end

---@package
---@param self RSAD.Controller
function rsad_controller.__load(self)
    self.stations = storage.stations or {}
    self.train_yards = storage.train_yards or {}
    self.scheduler.scripted_trains = storage.scripted_trains or {}
end

---@package
---@param self RSAD.Controller
---@param tick_data NthTickEventData
function rsad_controller.__nth_tick(self, tick_data)
    --- Check first if any shunting orders need to be issued
    if self.scheduler:update() then end

    ---@type TrainYard?
    local yard
    ---@type string?
    local k
    while active_yard ~= nil do
        yard = self.train_yards[active_yard]
        if yard then
            if yard:update(self) then break end
        end
        ---@diagnostic disable-next-line: unbalanced-assignments
        k, yard = next(self.train_yards, active_yard)
        active_yard = k
    end
    if not active_yard then active_yard = next(self.train_yards, active_yard) end
end

---@package
---@param self RSAD.Controller
---@param train LuaTrain
---@param old_state defines.train_state
function rsad_controller.__on_train_state_change(self, train, old_state)
    if train.state == defines.train_state.wait_station then
        local station = train.station and self.stations[train.station.unit_number]
        if not station then 
            ---Check for rail stop
            local schedule = train.schedule
            local record = schedule and schedule.records[schedule.current]
            local rail = record and record.rail
            if not record or not rail then return end
            local seek_direction = (record.rail_direction == defines.rail_direction.front and defines.rail_direction.back) or defines.rail_direction.front
            local stop = rail.get_rail_segment_stop(seek_direction)
            if stop then 
                station = self.stations[stop.unit_number]
            else
                local rail_end = rail.get_rail_end(seek_direction)
                rail_end.flip_direction()
                for i = 1, max_cargo_limit, 1 do
                    rail_end.move_to_segment_end()
                    stop = rail_end.rail.get_rail_segment_stop(rail_end.direction)
                    if stop then break end
                    rail_end.move_natural()
                end
                if stop then 
                    station = self.stations[stop.unit_number]
                else return end
            end
        end
        self:__on_arrive_at_station(station, train, old_state)
    end
end

---@package
---@param self RSAD.Controller
---@param entity LuaEntity
---@return boolean
function rsad_controller.__on_station_destroyed(self, entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return true end

    local station = self.stations[entity.unit_number]
    if not station then return true end

    self:decommision_station_from_yard(station, true)
    self.stations[station.unit_number] = nil
    return true
end

---@package
---@param self RSAD.Controller
---@param entity LuaEntity
---@return boolean
function rsad_controller.__on_station_built(self, entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return true end

    if entity.trains_limit > max_train_limit then
        entity.trains_limit = 1
    end
    
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

---@package
---@param self RSAD.Controller
---@param train LuaTrain?
---@return boolean
function rsad_controller.__on_train_removed(self, train)
    if not train then return true end

    for _, station in pairs(self.stations) do
        if station.parked_train == train.id then station.parked_train = nil end
    end

    self:remove_shunter(train.id)

    return true
end

---@package
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

function rsad_controller.__main_tick(self)
    storage.needs_tick = self.scheduler:on_tick()
    if not storage.needs_tick then script.on_event(defines.events.on_tick, nil) end --Unregister to save UPS
end

---@param self RSAD.Controller
function rsad_controller.register_events(self)
   events.register_init(function() self:__init() end)
   events.register_load(function() self:__load() end)
   events.register_break("name", names.entities.rsad_station, function(entity) return self:__on_station_destroyed(entity) end)
   events.register_break("rolling-stock", nil, function(entity) return self:__on_train_removed(entity.train) end)
   events.register_build("name", names.entities.rsad_station, function(entity) return self:__on_station_built(entity) end)
   events.register_paste(function(entity) self:__on_paste_settings(entity) end )
   events.register_train_handler(defines.events.on_train_changed_state, function(data) self:__on_train_state_change(data.train, data.old_state) end)
   script.on_nth_tick(ticks_per_update, function(tick_data) self:__nth_tick(tick_data) end)
   if storage.needs_tick then script.on_event(defines.events.on_tick, function(tick_data) self:__main_tick() end) end
   script.on_event(defines.events.on_player_created, function(data) self:__load() end)
end

---@param self RSAD.Controller
---@param signal SignalID?
---@return TrainYard?
function rsad_controller.get_train_yard_or_nil(self, signal)
    local hash = signal_hash(signal)
    return hash and self.train_yards[hash]
end

---Get or creates a train yard with specified signal
---@param self RSAD.Controller
---@param signal SignalID?
---@return TrainYard? yard
function rsad_controller.get_or_create_train_yard(self, signal)
    if not signal then return nil end
    local hash = signal_hash(signal)
    if not hash then return nil end
    self.train_yards[hash] = self.train_yards[hash] or create_train_yard(signal)
    return self.train_yards[hash]
end

---Returns false if needed to create, true if it was found
---@param self RSAD.Controller
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
---@param self RSAD.Controller
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
---@param self RSAD.Controller
---@param station RSADStation
---@param keep_network boolean? --If true, it will keep the network assigned in the station. Used only for destroying
function rsad_controller.decommision_station_from_yard(self, station, keep_network)
    if not station then return end
    local success, entity, data = get_station_data(station)
    if not success then
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
        self.stations[station.unit_number] = nil
    end
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
    self.stations[station.unit_number] = station
    return new_yard:add_or_update_station(station)
end

---comment
---@param self RSAD.Controller
---@param train_id integer
---@param yard TrainYard
function rsad_controller.assign_shunter(self, train_id, yard)
    yard:add_new_shunter(train_id)
end

---comment
---@param self RSAD.Controller
---@param train_id integer
function rsad_controller.remove_shunter(self, train_id)
    for _, yard in pairs(self.train_yards) do
        yard:remove_shunter(train_id)
    end
end

---@package
---@param self RSAD.Controller
---@param station RSADStation
---@param train LuaTrain
---@param old_state defines.train_state
function rsad_controller.__on_arrive_at_station(self, station, train, old_state)
    local success, station_entity, data = get_station_data(station)
    if not success then return end
    local yard = self:get_train_yard_or_nil(data.network)
    if yard then
        if data.type == rsad_station_type.shunting_depot then
            self:assign_shunter(train.id, yard)
        else
            local train_data = yard.shunter_trains[train.id]
            local is_shunter = train_data ~= nil
            if is_shunter then
                if data.type == rsad_station_type.import then
                    if train_data.current_stage == rsad_shunting_stage.delivery then
                        self:attempt_couple_at_station(train, station, train_data.pickup_info)
                        station.assignments = station.assignments - 1
                    elseif train_data.current_stage == rsad_shunting_stage.sort_imports then
                        local decoupled, new_train = self:decouple_all_cargo(train, station, is_shunter)
                        if not decoupled or not new_train then
                            game.print("Failed to decouple at " .. (train.front_stock and train.front_stock.gps_tag or "nil"))
                            return
                        end
                        train = new_train
                        ---TODO CONTINUE SORT
                    end
                elseif data.type == rsad_station_type.request then 
                    if train_data.current_stage == rsad_shunting_stage.delivery then
                        local decoupled, new_train = self:decouple_all_cargo(train, station, is_shunter)
                        if not decoupled or not new_train then
                            game.print("Failed to decouple at " .. (train.front_stock and train.front_stock.gps_tag or "nil"))
                            return
                        end
                        train = new_train
                        self.scheduler:check_and_return_shunter(train, yard)
                        station.assignments = station.assignments - 1
                    elseif train_data.current_stage == rsad_shunting_stage.clear_empty then
                        self:attempt_couple_at_station(train, station)
                        station.assignments = station.assignments - 1
                    end
                elseif data.type == rsad_station_type.empty_staging then
                    self:attempt_merge_at_station(train, station)
                    station.assignments = station.assignments - 1
                end
            else
                if data.type == rsad_station_type.import then
                    local decoupled, new_train = self:decouple_all_cargo(train, station, is_shunter)
                    if not decoupled or not new_train then
                        game.print("Failed to decouple at " .. (train.front_stock and train.front_stock.gps_tag or "nil"))
                        return
                    end
                    train = new_train
                end
            end
        end

    end
end

function rsad_controller.trigger_tick(self)
    storage.needs_tick = true
    script.on_event(defines.events.on_tick, function(tick_data) self:__main_tick() end)
end

require("scripts.rsad.coupling") --Coupling Module added to rsad_controller
return rsad_controller