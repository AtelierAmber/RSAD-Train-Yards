require("scripts.rsad.station")
require("scripts.rsad.util")
require("scripts.rsad.station-actions")
require("scripts.defines")

---@type flib_queue
queue = require("__flib__.queue")
---@type flib_math
fmath = require("__flib__.math")

-- TODO: Expand to inter-yard deliveries

---@class (exact) ScriptedTrainDestination
---@field public train LuaTrain
---@field public stop_distance number
---@field public brake_force number
---@field public traveled number
---@field public stopping boolean?
---@field public await AsyncAwait

---@class PendingChange
---@field public station RSAD.Station
---@field public create_schedule fun(yard:RSAD.TrainYard, ...:any): ScheduleRecord[], RSAD.TrainYard.ShuntingData

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
local function generate_target_record(target_station, reversed)
    local target_entity = game.get_entity_by_unit_number(target_station.unit_number)
    if not target_entity then return {} end
    local target_rail = target_entity.connected_rail
    local reversed_rail_direction = target_entity.connected_rail_direction == defines.rail_direction.back and defines.rail_direction.front or defines.rail_direction.back

    ---@type ScheduleRecord
    return {
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
---@param item SignalID?
---@return RSAD.Station?, RSAD.Station.Data?
local function get_next_providing_station(yard, item)
    local request_hash = signal_hash(item)
    local import = yard[rsad_station_type.import][request_hash] --[[@type table<uint, RSAD.Station>]]
    if not import then return nil end

    for unit, station in pairs(import) do
        data_success, station_entity, station_data = get_station_data(station)
        if ((station.incoming + table_size(station_entity.get_train_stop_trains())) < station_data.train_limit) and station.parked_train then
            return station, station_data
        end
    end

    return nil
end

---@param yard RSAD.TrainYard
---@param requester_station RSAD.Station
---@return ScheduleRecord[]?, RSAD.TrainYard.ShuntingData?
local function item_request_schedule(yard, requester_station)
    ---Create request station record
    local data_success, station_entity, station_data = get_station_data(requester_station)
    if not data_success then return nil end
    ---@type ScheduleRecord[]
    local request_record = generate_target_record(requester_station, station_data.reversed_shunting)
    local records = {
        [1] = request_record
    }
    ---@type RSAD.TrainYard.ShuntingData
    local new_data = { current_stage = rsad_shunting_stage.delivery, pickup_info = station_data.subinfo, scheduled_stations = {} } 
    table.insert(new_data.scheduled_stations, 1, requester_station)
    ---Check for turnabout
    local turnabout_station = yard[rsad_station_type.turnabout][rsad_shunting_stage.delivery]
    local turnabout_record = nil
    if turnabout_station then
        turnabout_record = generate_target_record(turnabout_station, false)
        turnabout_record.wait_conditions = nil
        table.insert(records, 1, turnabout_record)
        table.insert(new_data.scheduled_stations, 1, turnabout_station)
    end
    ---Create pickup record
    local input_station, input_station_data = get_next_providing_station(yard, station_data.request)
    if not input_station then return nil end
    data_success, station_entity, station_data = get_station_data(input_station)
    if data_success then
        table.insert(records, 1, generate_target_record(input_station, station_data.reversed_shunting))
        table.insert(new_data.scheduled_stations, 1, input_station)
    else return nil end
    
    return records, new_data
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
    local request_hash = signal_hash(data.request)
    if (not data.request or not yard[rsad_station_type.import] or 
        yard[rsad_station_type.import][request_hash] == nil or 
        next(yard[rsad_station_type.import][request_hash]) == nil) or
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
---@return ScheduleRecord[]?, RSAD.TrainYard.ShuntingData?
local function remove_wagon_schedule(yard, removal_station)
    local data_success, station_entity, station_data = get_station_data(removal_station)
    if not data_success then return nil end

    if not removal_station.parked_train then return nil end
    local parked_train = game.train_manager.get_train_by_id(removal_station.parked_train)
    if not parked_train then return nil end
    local front, dir = get_front_stock(parked_train, station_entity)
    local rail_end = (dir == defines.rail_direction.front and parked_train.back_end) or parked_train.front_end
    if not rail_end.move_forward(defines.rail_connection_direction.straight) then if not rail_end.move_forward(defines.rail_connection_direction.right) then rail_end.move_forward(defines.rail_connection_direction.left) end end
    rail_end.flip_direction()
    ---@type ScheduleRecord[]
    local pickup_record = default_rail_record(rail_end)
    local records = {
        [1] = pickup_record
    }
    ---@type RSAD.TrainYard.ShuntingData
    local new_data = { current_stage = rsad_shunting_stage.clear_empty, pickup_info = #parked_train.carriages, scheduled_stations = {} } 
    table.insert(new_data.scheduled_stations, 1, removal_station)
    ---Check for turnabout
    local turnabout_station = yard[rsad_station_type.turnabout][rsad_shunting_stage.clear_empty]
    local turnabout_record = nil
    if turnabout_station then
        turnabout_record = generate_target_record(turnabout_station, false)
        turnabout_record.wait_conditions = nil
        table.insert(records, turnabout_record)
        table.insert(new_data.scheduled_stations, turnabout_station)
    end
    ---Dropoff record
    local empty_stagings = yard[rsad_station_type.empty_staging] --[[@type table<integer, RSAD.Station>]]
    local dropoff = nil --[[@type RSAD.Station?]]
    for unit, empty_station in pairs(empty_stagings) do
        if empty_station.incoming > 0 then goto continue end
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
        local dropoff_record = generate_target_record(dropoff, false)
        table.insert(records, dropoff_record)
        table.insert(new_data.scheduled_stations, dropoff)
    else return nil end

    return records, new_data
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
    local return_depot_start --[[@type RailEndGoal]]
    local free_depot_starts = {} --[[@type table<number, RailEndStart>]]
    local free_depot_stations = {} --[[@type table<number, RSAD.Station>]]
    for _, depot in pairs(yard[rsad_station_type.shunting_depot]) do
        ---@cast depot RSAD.Station
        if not depot.parked_train and depot.incoming <= 0 then
            local target_entity = game.get_entity_by_unit_number(depot.unit_number)
            local target_rail = target_entity and target_entity.connected_rail
            if not target_rail then goto continue end
            local reversed_rail_direction = target_entity.connected_rail_direction == defines.rail_direction.back and defines.rail_direction.front or defines.rail_direction.back
            free_depot_starts[#free_depot_starts+1] = {rail = target_rail, direction = reversed_rail_direction}
            free_depot_stations[#free_depot_stations+1] = depot
        end
        ::continue::
    end
    local path = game.train_manager.request_train_path({type = "any-goal-accessible", starts = free_depot_starts, goals = {train.front_end, train.back_end}, train = train, in_chain_signal_section = false})

    if path.found_path then
        return_depot_start = free_depot_starts[path.start_index]
        local reversed_rail_direction = return_depot_start.direction == defines.rail_direction.back and defines.rail_direction.front or defines.rail_direction.back
        local records = {
            [1] = {
                rail = return_depot_start.rail,
                rail_direction = reversed_rail_direction,
                wait_conditions = {
                    {
                        type = "time",
                        ticks = 2
                    }
                }
            }
        }
        train.schedule = {current = 1, records = records}
        train.manual_mode = false
        local shunting_data = yard.shunter_trains[train.id]
        shunting_data.current_stage = rsad_shunting_stage.return_to_depot
        shunting_data.pickup_info = 0
        shunting_data.scheduled_stations = {[1] = free_depot_stations[path.start_index]}
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
        ---Try to create schedule
        local records, new_data = change.create_schedule(yard, change.station)
        if not records then goto tick_loop end
        ---@type TrainSchedule
        local schedule = { current = 1, records = records}

        train.schedule = schedule
        train.manual_mode = false

        for _, visit in pairs(new_data.scheduled_stations) do
            visit.incoming = visit.incoming + 1
        end
        local parked = self.controller.station_assignments[train.id]
        if parked then
            self.controller:free_parked_station(parked)
        end
        shunters[train.id] = new_data
        return true
    end

    return false
end

--#region SCRIPTED TRAIN MOVEMENT

---@param self RSAD.Scheduler
---@param train LuaTrain
---@param await AsyncAwait
function scheduler.on_scripted_stop(self, train, await)
    local schedule = train.get_schedule()
    schedule.remove_record({schedule_index = 1})
    if await.scope then
        RSAD_Actions.continue_actionset_execution(await, train, self.controller)
    else
        train.manual_mode = false
    end
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
    local brake_comp = math.min(1, (dist_to_start / brake_distance)) * brake_force --Distributes an adjustment factor across the braking distance, capped to brake_force (brake_force x2)
    local to_brake = dist_to_start <= (brake_force * 0.25)
    local decel = (to_brake and math.max(0, brake_force + brake_comp)) or 0 

    return to_brake, decel
end

---@param self RSAD.Scheduler
---@return boolean --false if no update is needed
function scheduler.process_script_movement(self)
    local stopped_trains = {} --[[@type table<number, ScriptedTrainDestination>]]
    local killed = {} --[[@type table<number, number>]]
    local updated = false
    for id, data in pairs(self.scripted_trains) do
        if not data.train or not data.train.valid then killed[id] = id goto continue end
        if data.stopping and not data.train.manual_mode then killed[id] = id goto continue end --Train was manually changed by player and is no longer controlled by script

        updated = true
        local speed = data.train.speed
        
        local eff_brake = data.brake_force / data.train.weight
        local braking, decel = calculate_brake_force(data.traveled, eff_brake, speed, data.stop_distance)
        local speed_dir = fmath.sign(speed)
        if braking or data.stopping then
            decel = decel * speed_dir
            data.stopping = true
            data.train.manual_mode = true
            speed = (speed_dir > 0 and math.max(0, speed - decel)) or fmath.min(0, speed - decel)
        end

        data.traveled = data.traveled + math.abs(speed)
        if data.stopping and ((speed * speed_dir) <= 0.0) then --If speed_dir is backward will multiply by -1 such that it checks it as if it were forward
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
        self:on_scripted_stop(data.train, data.await)
    end

    return updated
end

---Moves a train distance along its current path
---@param self RSAD.Scheduler
---@param train LuaTrain
---@param distance uint --Number of carriages to move. If negative will count in reverse
---@return AsyncAwait
function scheduler.move_train_by_distance(self, train, distance)
    local brake_force = 0.0
    local brake_multiplier = nil
    for _, l in pairs(train.carriages) do
        brake_multiplier = 1.0 + l.force.train_braking_force_bonus
        brake_force = brake_force + l.prototype.braking_force
    end
    brake_force = brake_force * (brake_multiplier or 1.0)

    local await = {complete = false} --[[@type AsyncAwait]]
    local train_data = {train = train, brake_force = brake_force, stop_distance = distance, traveled = 0, await = await} --[[@type ScriptedTrainDestination]]

    self.scripted_trains[train.id] = train_data

    self.controller:trigger_tick()

    return await
end

--#endregion

--- #region SORTING IMPORT MULTI-INGREDIENT ---

---@param self RSAD.Scheduler
---@param incoming LuaTrain
---@param station RSAD.Station
function scheduler.on_receive_multi_import(self, incoming, station)
    local wagons = incoming.cargo_wagons
end

---@param self RSAD.Scheduler
---@return boolean --false if no more needed
function scheduler.on_tick(self)
    return self:process_script_movement()
end

--- #endregion ---
return scheduler