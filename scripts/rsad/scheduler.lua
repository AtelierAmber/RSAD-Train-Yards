require("scripts.rsad.station")

---@type flib_queue
queue = require("__flib__.queue")
-- TODO: Expand to inter-yard deliveries

---@class PendingChange
---@field public station RSADStation
---@field public create_schedule fun(yard:TrainYard, ...:any): ScheduleRecord[]

---@class scheduler
scheduler = {
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
    
    ---@type ScheduleRecord
    return {
        station = reversed and nil or target_entity.backer_name,
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

---@param controller rsad_controller
---@param station RSADStation
---@return boolean
local function station_is_pending(controller, station)
    for change in queue.iter(controller.scheduler.pending_changes) do
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
    local records = {
        [1] = default_target_record(requester_station, station_data.reversed_shunting)
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
       (next(yard.shunter_trains) == nil) or station_is_pending(controller, station) then
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
---@param controller rsad_controller
---@return boolean, uint? --- Whether or not the request was successful, error number (nil if successful) 
function scheduler.queue_shunt_wagon_to_empty(self, controller, station)

end

---@param self scheduler
---@param train LuaTrain
---@param old_state defines.train_state
---@param return_depot RSADStation?
function scheduler.manage_train_state_change(self, train, old_state, return_depot)
    local schedule = train.schedule
    if train.state == defines.train_state.wait_station and schedule and schedule.current == #schedule.records and return_depot then
        local records = {
            [1] = default_target_record(return_depot, false)
        }
        train.schedule = {current = 1, records = records}
    end
end

---@param self scheduler
---@param controller rsad_controller
---@return boolean ---False if no update was necessary. True if an update was processed
function scheduler.tick(self, controller)
    ::tick_loop::
    local change = queue.pop_front(self.pending_changes)
    if not change then return false end

    local data_scuccess, station_entity, station_data = get_station_data(change.station)
    if not data_scuccess or not station_entity or not station_data or not station_data.network then goto tick_loop end
    local yard = controller:get_train_yard_or_nil(station_data.network)
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

return scheduler