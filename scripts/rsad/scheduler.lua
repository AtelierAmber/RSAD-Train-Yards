require("scripts.rsad.station")
require("scripts.rsad.util")
require("scripts.rsad.train-actions")

---@type flib_queue
queue = require("__flib__.queue")
-- TODO: Expand to inter-yard deliveries

---@class ScriptedTrainDestination
---@field public train LuaTrain
---@field public stop_distance number
---@field public brake_force number
---@field public stopping boolean
---@field public traveled number
---@field public is_forward boolean?
---@field public decouple_at LuaEntity
---@field public decouple_dir defines.rail_direction
---@field public network string
---@field public station RSAD.Station

---@class PendingChange
---@field public station RSAD.Station
---@field public create_schedule fun(yard:RSAD.TrainYard, ...:any): ScheduleRecord[], RSAD.TrainYard.ShuntingData, RSAD.Station[]

---@class RSAD.Scheduler
scheduler = {
    controller = nil, --[[@type RSAD.Controller]]
    scripted_trains = {}, --[[@type table<uint, ScriptedTrainDestination>]]
    pending_changes = queue.new() --[[@type flib.Queue<PendingChange>]]
}

local next = next -- Assign local table next for indexing speed

---@param target_station RSAD.Station
---@param reversed boolean
---@return ScheduleRecord
local function default_target_record(target_station, reversed)
    local target_entity = game.get_entity_by_unit_number(target_station.unit_number)
    if not target_entity then return {} end
    local target_rail = target_entity.connected_rail
    local reversed_rail_direction = target_entity.connected_rail_direction == defines.rail_direction.back and defines.rail_direction.front or defines.rail_direction.back
    local station_name = nil
    if not reversed then station_name = target_entity.backer_name end

    ---@type ScheduleRecord
    return {
        station = station_name,
        rail = target_rail,
        rail_direction = reversed and reversed_rail_direction or target_entity.connected_rail_direction,
        wait_conditions = {
            {
                type = "time",
                ticks = 2
            }
        }
    }
end

---@param rail LuaRailEnd
---@return ScheduleRecord
local function default_rail_record(rail)
    ---@type ScheduleRecord
    return {
        rail = rail.rail,
        rail_direction = rail.direction,
        wait_conditions = {
            {
                type = "time",
                ticks = 2
            }
        }
    }
end

---@param station RSAD.Station
---@return boolean
local function station_is_pending(self, station)
    for _, change in queue.iter(self.pending_changes) do
        if change.station.unit_number == station.unit_number then 
            return true
        end 
    end
    return false
end

---@param yard RSAD.TrainYard
---@param item string?
---@param train_limit integer
---@return RSAD.Station?
local function get_next_providing_station(yard, item, train_limit)
    local import = yard[rsad_station_type.import][item] --[[@type table<uint, RSAD.Station>]]
    if not import then return nil end

    for unit, station in pairs(import) do
        if station.assignments < train_limit and station.parked_train then
            return station
        end
    end

    return nil
end

---@param yard RSAD.TrainYard
---@param requester_station RSAD.Station
---@return ScheduleRecord[]?, RSAD.TrainYard.ShuntingData?, RSAD.Station[]?
local function item_request_schedule(yard, requester_station)
    ---Create request station record
    local data_success, station_entity, station_data = get_station_data(requester_station)
    if not data_success then return nil end
    ---@type ScheduleRecord[]
    local request_record = default_target_record(requester_station, station_data.reversed_shunting)
    local records = {
        [1] = request_record
    }
    local visited_stations = {}
    table.insert(visited_stations, requester_station)
    ---@type RSAD.TrainYard.ShuntingData
    local new_data = { current_stage = rsad_shunting_stage.delivery, pickup_info = station_data.subinfo } 
    ---Check for turnabout
    local turnabout_station = yard[rsad_station_type.turnabout][rsad_shunting_stage.delivery]
    local turnabout_record = nil
    if turnabout_station then
        turnabout_record = default_target_record(turnabout_station, false)
        turnabout_record.wait_conditions = nil
        table.insert(records, 1, turnabout_record)
        table.insert(visited_stations, turnabout_station)
    end
    ---Create pickup record
    local input_station = get_next_providing_station(yard, station_data.item and station_data.item.name, station_data.train_limit)
    if not input_station then return nil end
    data_success, station_entity, station_data = get_station_data(input_station)
    if data_success then
        table.insert(records, 1, default_target_record(input_station, station_data.reversed_shunting))
        table.insert(visited_stations, input_station)
    else return nil end
    
    return records, new_data, visited_stations
end

---@param self RSAD.Scheduler
---@param station RSAD.Station
---@return boolean, uint? --- Whether or not the request was successful, error number (nil if successful) 
function scheduler.queue_station_request(self, station)
    if not station then return false, 3 end
    local success, station_entity, data = get_station_data(station)
    if not success then return false, 4 end
    
    local yard = self.controller:get_or_create_train_yard(data.network) ---@type RSAD.TrainYard?
    if not yard then return false, 2 end

    ---Preliminary assertions
    if (not data.item or not yard[rsad_station_type.import] or 
        yard[rsad_station_type.import][data.item.name] == nil or 
        next(yard[rsad_station_type.import][data.item.name]) == nil) or
       (next(yard.shunter_trains) == nil) or station_is_pending(self, station) then
       return false --Failed to queue request, no Error 
    end

    ---@type PendingChange
    local queued_data = {
        station = station,
        create_schedule = item_request_schedule
    }

    queue.push_back(self.pending_changes, queued_data)

    return true
end

--#region EMPTY WAGON SHUNTING

---@param yard RSAD.TrainYard
---@param removal_station RSAD.Station
---@return ScheduleRecord[]?, RSAD.TrainYard.ShuntingData?, RSAD.Station[]?
local function remove_wagon_schedule(yard, removal_station)
    local data_success, station_entity, station_data = get_station_data(removal_station)
    if not data_success then return nil end

    if not removal_station.parked_train then return nil end
    local parked_train = game.train_manager.get_train_by_id(removal_station.parked_train)
    if not parked_train then return nil end
    local front, dir = get_front_stock(parked_train, station_entity)
    local rail_end = (dir == defines.rail_direction.front and parked_train.back_end) or parked_train.front_end
    rail_end.move_natural()
    rail_end.flip_direction()
    ---@type ScheduleRecord[]
    local pickup_record = default_rail_record(rail_end)
    local records = {
        [1] = pickup_record
    }
    local visited_stations = {}
    table.insert(visited_stations, removal_station)
    ---@type RSAD.TrainYard.ShuntingData
    local new_data = { current_stage = rsad_shunting_stage.clear_empty, pickup_info = #parked_train.carriages } 
    ---Check for turnabout
    local turnabout_station = yard[rsad_station_type.turnabout][rsad_shunting_stage.clear_empty]
    local turnabout_record = nil
    if turnabout_station then
        turnabout_record = default_target_record(turnabout_station, false)
        turnabout_record.wait_conditions = nil
        table.insert(records, turnabout_record)
        table.insert(visited_stations, turnabout_station)
    end
    ---Dropoff record
    local empty_stagings = yard[rsad_station_type.empty_staging] --[[@type table<integer, RSAD.Station>]]
    local dropoff = nil --[[@type RSAD.Station?]]
    for unit, empty_station in pairs(empty_stagings) do
        if empty_station.assignments > 0 then goto continue end
        if not empty_station.parked_train then  
            dropoff = empty_station
            break
        else
            local wagon_count = #(game.train_manager.get_train_by_id(empty_station.parked_train).carriages)
            local empty_data_success, empty_station_entity, empty_data = get_station_data(empty_station)
            if wagon_count < empty_data.subinfo then
                dropoff = empty_station
                break
            end
        end
        ::continue::
    end
    if dropoff then
        local dropoff_record = default_target_record(dropoff, false)
        table.insert(records, dropoff_record)
        table.insert(visited_stations, dropoff)
    else return nil end

    return records, new_data, visited_stations
end

---@param self RSAD.Scheduler
---@param station RSAD.Station
---@return boolean, uint? --- Whether or not the request was successful, error number (nil if successful) 
function scheduler.queue_shunt_wagon_to_empty(self, station)
    if not station then return false, 3 end
    local success, station_entity, data = get_station_data(station)
    if not success then return false, 4 end
    
    local yard = self.controller:get_or_create_train_yard(data.network) ---@type RSAD.TrainYard?
    if not yard then return false, 2 end

    ---Preliminary assertions
    if not yard[rsad_station_type.empty_staging] or (next(yard.shunter_trains) == nil) or station_is_pending(self, station) then
       return false --Failed to queue request, no Error 
    end

    ---@type PendingChange
    local queued_data = {
        station = station,
        create_schedule = remove_wagon_schedule
    }

    queue.push_back(self.pending_changes, queued_data)

    return true
end

--#endregion

---@param self RSAD.Scheduler
---@param train LuaTrain
---@param yard RSAD.TrainYard
function scheduler.return_shunter(self, train, yard)
    local return_depot = select(2, next(yard[rsad_station_type.shunting_depot]))
      if return_depot then
        local records = {
            [1] = default_target_record(return_depot, false)
        }
        train.schedule = {current = 1, records = records}
        train.manual_mode = false
        yard.shunter_trains[train.id].current_stage = rsad_shunting_stage.return_to_depot
        yard.shunter_trains[train.id].pickup_info = 0
    end
end

---@param self RSAD.Scheduler
---@param train LuaTrain
---@param yard RSAD.TrainYard
function scheduler.check_and_return_shunter(self, train, yard)
    local schedule = train.schedule
    if schedule and schedule.current == #schedule.records then
        self:return_shunter(train, yard)
    end
end

---@param self RSAD.Scheduler
---@return boolean ---False if no update was necessary. True if an update was processed
function scheduler.update(self)
    ::tick_loop::
    local change = queue.pop_front(self.pending_changes)
    if not change then return false end

    local data_success, station_entity, station_data = get_station_data(change.station)
    if not data_success then goto tick_loop end
    local yard = self.controller:get_train_yard_or_nil(station_data.network)
    if not yard then goto tick_loop end

    ---Try to create schedule
    local records, new_data, visiting_stations = change.create_schedule(yard, change.station)
    if not records then goto tick_loop end
    ---@type TrainSchedule
    local schedule = { current = 1, records = records}

    ---Find an available and most convenient shunter
    local shunters =  yard.shunter_trains
    local first_idle = nil
    local first_finishing = nil
    for id, shunting_data in pairs(shunters) do
        if shunting_data.current_stage == rsad_shunting_stage.available and not first_idle then
            first_idle = id
        -- elseif shunting_data.current_stage == rsad_shunting_stage.return_to_depot and not first_finishing then
        --     ---Ensure Pathing is possible
        --     local shunter_train = game.train_manager.get_train_by_id(id)
        --     if shunter_train and game.train_manager.request_train_path({train = shunter_train, shortest_path = true, search_direction = "any-direction-with-locomotives", goals = {{train_stop = station_entity}}}).found_path then
        --         first_finishing = id
        --     end
        end
    end

    local train = game.train_manager.get_train_by_id(first_finishing or first_idle or 0)
    if train then
        train.schedule = schedule
        train.manual_mode = false

        shunters[train.id] = new_data
        for _, visit in pairs(visiting_stations) do
            visit.assignments = visit.assignments + 1
        end
        return true
    end

    return false
end

---@param traveled number --Distance traveled so far
---@param brake_force number
---@param speed number --Train Speed
---@param destination number --Destination travelled_distance
---@return boolean braking, number force
local function calculate_brake_force(traveled, brake_force, speed, destination)
    local brake_distance = speed * speed / brake_force * 0.5
    local brake_start = destination - brake_distance
    local dist_to_start = (brake_start - traveled)
    local brake_comp = (dist_to_start / brake_distance) * brake_force
    local decel = ((dist_to_start <= 0) and math.max(0, brake_force + brake_comp)) or 0 

    return (dist_to_start <= 0), decel
end

---@param self RSAD.Scheduler
---@param data ScriptedTrainDestination
function scheduler.on_scripted_stop(self, data)
    local yard = self.controller.train_yards[data.network or ""]
    if yard then
        local train_info = yard.shunter_trains[data.train.id]
        if train_info then
            if train_info.current_stage == rsad_shunting_stage.delivery then
                self.controller:decouple_and_assign(data.train, data.decouple_at, data.decouple_dir, data.network, data.station)
            elseif train_info.current_stage == rsad_shunting_stage.clear_empty then
                local decoupled, new_train = self.controller:decouple_all_cargo(data.train, data.station, true)
                if decoupled then 
                    self:return_shunter(new_train, yard)
                else
                    game.print("Failed to decouple at " .. (data.train and data.train.valid and data.train.front_stock and data.train.front_stock.gps_tag or "nil"))
                end
            end
        end
    else
        self.controller:decouple_and_assign(data.train, data.decouple_at, data.decouple_dir, data.network, data.station)
    end
end

---@param self RSAD.Scheduler
---@return boolean --false if no update is needed
function scheduler.process_script_movement(self)
    local stopped_trains = {}
    local killed = {}
    local updated = false
    for id, data in pairs(self.scripted_trains) do
        updated = true
        if not data.train or not data.train.valid then killed[id] = id goto continue end
        local path = data.train.path
        local speed = data.train.speed
        if path then
            data.is_forward = path.is_front
        end
        
        local eff_brake = data.brake_force / data.train.weight
        local braking, decel = calculate_brake_force(data.traveled, eff_brake, speed, data.stop_distance)
        if braking or data.stopping then
            decel = decel * (data.is_forward and 1 or -1) 
            data.stopping = true
            data.train.manual_mode = true
            speed = speed - decel
        end
        data.traveled = data.traveled + math.abs(speed)
        if data.stopping and (math.abs(speed) <= 0.0001) then
            speed = 0
            stopped_trains[id] = data
        end
        data.train.speed = speed
        ::continue::
    end

    for _, id in pairs(killed) do
        self.scripted_trains[id] = nil
    end

    for id, data in pairs(stopped_trains) do
        self.scripted_trains[id] = nil
        self:on_scripted_stop(data)
    end

    return updated
end

---@param self RSAD.Scheduler
---@return boolean --false if no more needed
function scheduler.on_tick(self)
    return self:process_script_movement()
end

---comment
---@param self RSAD.Scheduler
---@param train LuaTrain
---@param move_from LuaEntity --Carriage that marks the destination for [count away] trains
---@param count uint --Number of carriages to move. If negative will count in reverse
---@param network string --Network this train is assigned in
---@param station RSAD.Station --Station to assign the decoupled train to
function scheduler.move_train_by_wagon_count(self, train, move_from, count, network, station)
    local brake_force = 0.0
    local brake_multiplier = nil
    for _, l in pairs(train.carriages) do
        brake_multiplier = 1.0 + l.force.train_braking_force_bonus
        brake_force = brake_force + l.prototype.braking_force
    end
    brake_force = brake_force * (brake_multiplier or 1.0)
    local stop_distance = 0.0
    
    local direction = ((count < 0 and defines.rail_direction.back) or defines.rail_direction.front)
    local carriage = move_from --[[@type LuaEntity?]]
    local next_carriage = carriage --[[@type LuaEntity?]]
    count = math.abs(count)
    for i = 1, count, 1 do
        carriage = next_carriage
        next_carriage = carriage and carriage.get_connected_rolling_stock(direction)
        if not next_carriage then return end
        local distance = (carriage and carriage.prototype.joint_distance + carriage.prototype.connection_distance) or 0
        stop_distance = stop_distance + distance
    end
    next_carriage = carriage and carriage.get_connected_rolling_stock(direction)
    --stop_distance = stop_distance + (next_carriage and ((next_carriage.prototype.joint_distance / 2)) or 0.0)

    local train_data = {train = train, brake_force = brake_force, stop_distance = stop_distance, stopping = false, traveled = 0, decouple_at = carriage, decouple_dir = direction, network = network, station = station} --[[@type ScriptedTrainDestination]]

    self.scripted_trains[train.id] = train_data

    self.controller:trigger_tick()
end

---comment
---@param self RSAD.Scheduler
---@param train LuaTrain
---@param decouple_at LuaEntity -- Which carriage to decouple from
---@param decouple_dir defines.rail_direction
---@param distance uint --Number of carriages to move. If negative will count in reverse
---@param network string --Network this train is assigned in
---@param station RSAD.Station --Station to assign the decoupled train to
function scheduler.move_train_by_distance(self, train, decouple_at, decouple_dir, distance, network, station)
    local brake_force = 0.0
    local brake_multiplier = nil
    for _, l in pairs(train.carriages) do
        brake_multiplier = 1.0 + l.force.train_braking_force_bonus
        brake_force = brake_force + l.prototype.braking_force
    end
    brake_force = brake_force * (brake_multiplier or 1.0)

    local train_data = {train = train, brake_force = brake_force, stop_distance = distance, stopping = false, traveled = 0, decouple_at = decouple_at, decouple_dir = decouple_dir, network = network, station = station} --[[@type ScriptedTrainDestination]]

    self.scripted_trains[train.id] = train_data

    self.controller:trigger_tick()
end


--- #region SORTING IMPORT MULTI-INGREDIENT ---

---@param self RSAD.Scheduler
---@param incoming LuaTrain
---@param station RSAD.Station
function scheduler.on_receive_multi_import(self, incoming, station)
    local wagons = incoming.cargo_wagons
end

--- #endregion ---
return scheduler