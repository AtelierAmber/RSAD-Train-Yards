require("scripts.rsad.station")
require("scripts.rsad.util")

---@type flib_queue
queue = require("__flib__.queue")
-- TODO: Expand to inter-yard deliveries

---@class ScriptedTrainDestination
---@field public train LuaTrain
---@field public stop_distance number
---@field public brake_force number
---@field public stopping boolean
---@field public decel number?
---@field public is_forward boolean
---@field public decouple_at LuaEntity
---@field public decouple_dir defines.rail_direction
---@field public network string
---@field public station RSADStation

---@class PendingChange
---@field public station RSADStation
---@field public create_schedule fun(yard:TrainYard, ...:any): ScheduleRecord[]

---@class scheduler
scheduler = {
    controller = nil, --[[@type rsad_controller]]
    scripted_trains = {}, --[[@type table<uint, ScriptedTrainDestination>]]
    pending_changes = queue.new() --[[@type flib.Queue<PendingChange>]]
}

local next = next -- Assign local table next for indexing speed

---@param target_station RSADStation
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

---@param station RSADStation
---@return boolean
local function station_is_pending(self, station)
    for change in queue.iter(self.controller.scheduler.pending_changes) do
        if change.station.unit_number == station.unit_number then 
            return true
        end 
    end
    return false
end

---@param yard TrainYard
---@param item string?
---@return RSADStation?
local function get_next_providing_station(yard, item)
    local import = yard[rsad_station_type.import][item] --[[@type table<uint, RSADStation>]]
    if not import then return nil end

    for unit, station in pairs(import) do
        if station.parked_train then
            return station
        end
        return station
    end

    return nil
end

---@param yard TrainYard
---@param requester_station RSADStation
---@return ScheduleRecord[]?
local function item_request_schedule(yard, requester_station)
    ---Create request station record
    local data_scuccess, station_entity, station_data = get_station_data(requester_station)
    if not data_scuccess or not station_data then return nil end
    ---@type ScheduleRecord[]
    local request_record = default_target_record(requester_station, station_data.reversed_shunting)
    local records = {
        [1] = request_record
    }
    ---Check for turnabout
    local turnabout_station = yard[rsad_station_type.turnabout][rsad_shunting_stage.delivery]
    local turnabout_record = nil
    if turnabout_station then
        turnabout_record = default_target_record(turnabout_station, false)
        turnabout_record.wait_conditions = nil
        table.insert(records, 1, turnabout_record)
    end
    ---Create pickup record
    local input_station = get_next_providing_station(yard, station_data.item and station_data.item.name)
    if not input_station then return nil end
    data_scuccess, station_entity, station_data = get_station_data(input_station)
    if data_scuccess and station_data then
        table.insert(records, 1, default_target_record(input_station, station_data.reversed_shunting))
    end

    return records
end

---@param self scheduler
---@param controller rsad_controller
---@param station RSADStation
---@return boolean, uint? --- Whether or not the request was successful, error number (nil if successful) 
function scheduler.queue_station_request(self, controller, station)
    if not station then return false, 3 end
    local success, station_entity, data = get_station_data(station)
    if not success or not data then return false, 4 end
    
    local yard = controller:get_or_create_train_yard(data.network) ---@type TrainYard?
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

---@param self scheduler
---@param station RSADStation
---@return boolean, uint? --- Whether or not the request was successful, error number (nil if successful) 
function scheduler.queue_shunt_wagon_to_empty(self, station)

end

---@param self scheduler
---@param train LuaTrain
---@param return_depot RSADStation?
function scheduler.check_and_return_shunter(self, train, return_depot)
    local schedule = train.schedule
    if schedule and schedule.current == #schedule.records and return_depot then
        local records = {
            [1] = default_target_record(return_depot, false)
        }
        train.schedule = {current = 1, records = records}
        train.manual_mode = false
    end
end

---@param self scheduler
---@return boolean ---False if no update was necessary. True if an update was processed
function scheduler.update(self)
    ::tick_loop::
    local change = queue.pop_front(self.pending_changes)
    if not change then return false end

    local data_scuccess, station_entity, station_data = get_station_data(change.station)
    if not data_scuccess or not station_entity or not station_data or not station_data.network then goto tick_loop end
    local yard = self.controller:get_train_yard_or_nil(station_data.network)
    if not yard then goto tick_loop end

    ---Try to create schedule
    local records = change.create_schedule(yard, change.station)
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
        elseif shunting_data.current_stage == rsad_shunting_stage.return_to_depot then
            ---Ensure Pathing is possible
            local shunter_train = game.train_manager.get_train_by_id(id)
            if shunter_train and game.train_manager.request_train_path({train = shunter_train, shortest_path = true, search_direction = "any-direction-with-locomotives", goals = {{train_stop = station_entity}}}).found_path then
                first_finishing = id
            end
        end
    end

    local train = game.train_manager.get_train_by_id(first_finishing or first_idle or 0)
    if train then
        train.schedule = schedule
        train.manual_mode = false

        shunters[train.id].current_stage = rsad_shunting_stage.delivery
        change.station.assignments  = change.station.assignments + 1
        return true
    end

    return false
end

---@param path LuaRailPath
---@param brake_force number
---@param speed number --Train Speed
---@param destination number --Destination travelled_distance
---@return number force
local function calculate_brake_force(path, brake_force, speed, destination)
    local brake_distance = speed * speed / brake_force * 0.5
    local brake_start = destination - brake_distance
    local dist_to_start = (brake_start - path.travelled_distance)
    local decel = (dist_to_start <= 0.1) and math.max(0, brake_force - (dist_to_start * 0.01)) or 0 

    return decel
end

---@param self scheduler
---@param data ScriptedTrainDestination
function scheduler.on_scripted_stop(self, data)
    self.controller:decouple_at(data.train, data.decouple_at, data.decouple_dir, data.network, data.station)
end

---@param self scheduler
---@return boolean --false if no update is needed
function scheduler.process_script_movement(self)
    local stopped_trains = {}
    local updated = false
    for id, data in pairs(self.scripted_trains) do
        updated = true
        local path = data.train.path
        local speed = data.train.speed
        if path then
            data.is_forward = path.is_front
            local eff_brake = data.brake_force / data.train.weight
            local decel = calculate_brake_force(path, eff_brake, speed, data.stop_distance)
            if decel > (eff_brake * 0.75) then
                decel = decel * (data.is_forward and 1 or -1) 
                data.stopping = true
                data.decel = decel
                data.train.manual_mode = true
                speed = speed - decel
            end
        elseif data.stopping and data.decel then
            speed = speed - data.decel
        end
        if data.stopping and ((speed * (data.is_forward and 1 or -1)) <= 0.0001) then
            speed = 0
            stopped_trains[id] = data
        end
        data.train.speed = speed
        ::continue::
    end

    for id, data in pairs(stopped_trains) do
        self.scripted_trains[id] = nil
        self:on_scripted_stop(data)
    end

    return updated
end

---@param self scheduler
---@return boolean --false if no more needed
function scheduler.on_tick(self)
    return self:process_script_movement()
end

---comment
---@param self scheduler
---@param train LuaTrain
---@param move_from LuaEntity --Carriage that marks the destination for [count away] trains
---@param count uint --Number of carriages to move. If negative will count in reverse
---@param network string --Network this train is assigned in
---@param station RSADStation --Station to assign the decoupled train to
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
        local distance = carriage and carriage.prototype.joint_distance + carriage.prototype.connection_distance or 0
        stop_distance = stop_distance + distance and distance or 0.0
    end
    next_carriage = carriage and carriage.get_connected_rolling_stock(direction)
    stop_distance = stop_distance + (next_carriage and ((next_carriage.prototype.joint_distance / 2)) or 0.0)

    local train_data = {train = train, brake_force = brake_force, stop_distance = stop_distance, stopping = false, is_forward = true, decouple_at = carriage, decouple_dir = direction, network = network, station = station} --[[@type ScriptedTrainDestination]]

    self.scripted_trains[train.id] = train_data

    self.controller:trigger_tick()
end

return scheduler