require("scripts.rsad.train-yard")
require("scripts.rsad.util")


---@param self RSAD.Controller
---@param train LuaTrain
---@param direction defines.rail_direction
---@return integer new_train_id
function rsad_controller.couple_direction(self, train, direction)
    local old_id = train.id
    local connecting_stock = direction == (defines.rail_direction.front and train.carriages[0]) or train.carriages[#train.carriages]
    local connect_dir = connecting_stock.get_connected_rolling_stock(defines.rail_direction.front) and defines.rail_direction.back or defines.rail_direction.front
    if not connecting_stock.connect_rolling_stock(direction) then log("Failed to couple train [" .. train.id .. "]") return -1 end
    train = connecting_stock.train
    if not train then log("Train is nil after coupling train") return -1 end
    local new_id = train.id
    
    local parked_at = self.station_assignments[old_id]
    if parked_at then
        self:park_train_at_station(new_id, parked_at)
    end
    local shunter_network = self.shunter_networks[old_id]
    if shunter_network then
        local yard = self.train_yards[shunter_network]
        if yard then
            yard:redefine_shunter(old_id, new_id)
        end
    end

    return new_id
end

function rsad_controller.decouple_at(self, train, )

end

---@param self RSAD.Controller
---@param train LuaTrain
---@param station RSAD.Station
---@param count uint? -- If nil will couple all wagons
---@return boolean success
function rsad_controller.attempt_couple_at_station(self, train, station, count)
    local success, entity, station_data = get_station_data(station)
    if not success then return false end
    local old_train_id, old_train_length = train.id, table_size(train.carriages)
    local schedule = train.schedule

    local front_stock, front_direction = get_front_stock(train, entity)
    local connect_dir = front_stock.get_connected_rolling_stock(defines.rail_direction.front) and defines.rail_direction.back or defines.rail_direction.front
    if not front_stock.connect_rolling_stock(connect_dir) then return false end

    train = front_stock.train
    if not train then return false end

    train.schedule = schedule
    if schedule then train.go_to_station(schedule.current+1) end

    if count and (old_train_length + count) < table_size(train.carriages) then --- Start Distanced Disconnect if there are more wagons than needed
        station.parked_train = train.id
        local connected_stock = front_stock.get_connected_rolling_stock(connect_dir)
        if not connected_stock then return false end
        self.scheduler:move_train_by_wagon_count(train, connected_stock, count * ((connected_stock.is_headed_to_trains_front and -1) or 1), signal_hash(station_data.network) or "", station)
    else
        station.parked_train = nil
    end

    local new_train_id = train.id 

    local yard = self:get_train_yard_or_nil(station_data.network)
    if not yard then return true end

    yard:redefine_shunter(old_train_id, new_train_id)

    return true
end

---@param self RSAD.Controller
---@param train LuaTrain
---@param station RSAD.Station
---@return boolean success
function rsad_controller.attempt_merge_at_station(self, train, station)
    local success, entity, station_data = get_station_data(station)
    if not success then return false end
    local old_train_id = train.id
    local stop_distance = 0.0
    local train_length = 0.0
    local carriages = train.carriages
    local disconnect_from = nil --[[@type LuaEntity?]]
    for i, carriage in pairs(carriages) do
        local distance = carriage.prototype.joint_distance + carriage.prototype.connection_distance
        train_length = train_length + distance
        if carriage.type ~= "locomotive" then
            stop_distance = stop_distance + distance

            if not disconnect_from then
                prev_carriage = i > 1 and carriages[i-1]
                if prev_carriage and prev_carriage.type == "locomotive" then 
                    disconnect_from = prev_carriage 
                end
            end
        end
    end
    if not disconnect_from then return false end
    local schedule = train.schedule

    local front_stock, front_direction = get_front_stock(train, entity)
    local connect_dir = front_stock.get_connected_rolling_stock(defines.rail_direction.front) and defines.rail_direction.back or defines.rail_direction.front
    local merged = front_stock.connect_rolling_stock(connect_dir) 
    train = front_stock.train
    if not train then return false end
    --stop_distance = stop_distance + ((front_stock.prototype.joint_distance / 2))
    station.parked_train = train.id

    local connected_length = -train_length
    carriages = train.carriages
    for _, carriage in pairs(carriages) do
        local distance = carriage.prototype.joint_distance + carriage.prototype.connection_distance
        connected_length = connected_length + distance
    end
    
    local path_distance = -connected_length
    local connected_rail_end = train.get_rail_end(connect_dir)
    if not merged then -- Move past station
        connected_rail_end.move_to_segment_end()
        connected_rail_end.move_natural()
    end
    local connected_rail = connected_rail_end.rail
    while connected_rail and path_distance < stop_distance do
        path_distance = path_distance + connected_rail.get_rail_segment_length()
        connected_rail_end.move_to_segment_end()
        connected_rail_end.move_natural()
        connected_rail = connected_rail_end.rail
    end
    if not connected_rail or path_distance < 0 then return false end

    train.schedule = schedule
    local lua_schedule = train.get_schedule()
    lua_schedule.add_record({index = {schedule_index = 1}, temporary = true, rail = connected_rail, wait_conditions = {{type = "time", ticks = 2}}})
    lua_schedule.go_to_station(1)
    self.scheduler:move_train_by_distance(train, disconnect_from, disconnect_from.is_headed_to_trains_front and defines.rail_direction.front or defines.rail_direction.back, stop_distance, signal_hash(station_data.network) or "", station)

    local new_train_id = train.id

    local yard = self:get_train_yard_or_nil(station_data.network)
    if not yard then return true end

    yard:redefine_shunter(old_train_id, new_train_id)

    return true
end

---@param self RSAD.Controller
---@param train LuaTrain
---@param station RSAD.Station
---@return boolean success, LuaTrain new_train
function rsad_controller.decouple_all_cargo(self, train, station, is_shunter)
    local start, direction = get_back_cargo(train)

    local wagon = start
    local next_wagon = start --[[@as LuaEntity?]]
---@diagnostic disable-next-line: missing-return-value
    if wagon.type == "locomotive" then return false end
    while true do
        next_wagon = wagon.get_connected_rolling_stock(direction)
        assert(next_wagon ~= nil, "Failed to decouple. No Locomotive found to decouple from.")
        --[[@cast next_wagon LuaEntity]]
        if next_wagon.type == "locomotive" then break end
        wagon = next_wagon
    end
    
    local old_train_id = train.id
    local schedule = train.schedule --[[@as TrainSchedule]]
    ---@diagnostic disable-next-line: missing-return-value
    if not wagon.disconnect_rolling_stock(direction) then return false end
    train = next_wagon.train --[[@as LuaTrain]]
    local new_train_id = next_wagon.train.id or old_train_id
    if schedule.current < #schedule.records then
        schedule.current = schedule.current + 1
    end
    train.schedule = schedule
    train.manual_mode = false

---@diagnostic disable-next-line: missing-return-value
    if is_shunter then 
        local success, entity, station_data = get_station_data(station)
        ---@diagnostic disable-next-line: missing-return-value
        if success then
            local yard = self.train_yards[signal_hash(station_data.network)] --[[@type RSAD.TrainYard]]
            if yard then
                yard:redefine_shunter(old_train_id, new_train_id)
            end
        end
    end

    station.parked_train = wagon.train.id
    return true, train
end

---@param self RSAD.Controller
---@param train LuaTrain
---@param at LuaEntity
---@param direction defines.rail_direction
---@param network string
---@param assign_to RSAD.Station
function rsad_controller.decouple_and_assign(self, train, at, direction, network, assign_to)
    local old_train_id = train.id
    local schedule = train.schedule
    local other = at.get_connected_rolling_stock(direction)
    if at.disconnect_rolling_stock(direction) then
        local new_train_id = at.train.id
        at.train.schedule = schedule
        at.train.manual_mode = false
    
        local yard = self.train_yards[network]
        if not yard then return end
    
        yard:redefine_shunter(old_train_id, new_train_id)
        if other then
            assign_to.parked_train = other.train.id
        end
    end
end