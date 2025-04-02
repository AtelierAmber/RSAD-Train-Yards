require("scripts.rsad.train-yard")
require("scripts.rsad.util")


---@param self RSAD.Controller
---@param train LuaTrain
---@param direction defines.rail_direction
---@return integer new_train_id
function rsad_controller.couple_direction(self, train, direction)
    local old_id = train.id
    local old_lua_schedule = train.get_schedule()
    local old_group = old_lua_schedule.group
    local old_records = old_lua_schedule.get_records()
    local old_interrupts = old_lua_schedule.get_interrupts()
    local old_current = old_lua_schedule.current
    local connecting_stock = direction == (defines.rail_direction.front and train.carriages[0]) or train.carriages[#train.carriages]
    local connecting_id = connecting_stock and connecting_stock.train and connecting_stock.train.id
    local connect_dir = connecting_stock.get_connected_rolling_stock(defines.rail_direction.front) and defines.rail_direction.back or defines.rail_direction.front
    if not connecting_stock.connect_rolling_stock(connect_dir) then return old_id end --Should mean that there is no train to couple to. Continue execution
    train = connecting_stock.train
    if not train then log({"", "Train is nil after coupling train"}) return -1 end
    local new_id = train.id
    
    local parked_at = self.station_assignments[old_id] or self.station_assignments[connecting_id]
    if parked_at then
        self:park_train_at_station(new_id, parked_at)
    end
    self:redefine_shunter(old_id, new_id)

    ---Copy old schedule
    local new_schedule = train.get_schedule()
    new_schedule.group = old_group
    new_schedule.set_interrupts(old_interrupts)
    if old_records then new_schedule.set_records(old_records) end
    new_schedule.go_to_station(old_current)
    new_schedule.set_stopped(true)

    return new_id
end

---Splits [train] at location of [at] in [direction]. If parked, will assign the [direction] train unless [park_self]
---@param self RSAD.Controller
---@param train LuaTrain
---@param at LuaEntity
---@param direction defines.rail_direction
---@param park_self boolean
---@return integer new_train_id
function rsad_controller.decouple_at(self, train, at, direction, park_self)
    local old_id = train.id
    local old_lua_schedule = train.get_schedule()
    local old_group = old_lua_schedule.group
    local old_records = old_lua_schedule.get_records()
    local old_interrupts = old_lua_schedule.get_interrupts()
    local old_current = old_lua_schedule.current
    local other = at.get_connected_rolling_stock((at.is_headed_to_trains_front and direction) or ((direction == defines.rail_direction.front and defines.rail_direction.back) or defines.rail_direction.front))
    if not at.disconnect_rolling_stock((at.is_headed_to_trains_front and direction) or ((direction == defines.rail_direction.front and defines.rail_direction.back) or defines.rail_direction.front)) then  log({"", "Failed to decouple train [" .. train.id .. "]"}) return -1 end
    train = at.train
    if not train then log({"", "Train is nil after decoupling train"}) return -1 end
    local new_id = train.id

    local parked_at = self.station_assignments[old_id]
    if parked_at then
        if other and other.train and not park_self then
            ---Clear schedule to prevent overrides when coupling afterwards
            other.train.schedule = nil
            self:park_train_at_station(other.train.id, parked_at)
        else 
            self:park_train_at_station(new_id, parked_at)
        end
    end
    
    self:redefine_shunter(old_id, new_id)

    ---Copy old schedule
    local new_schedule = train.get_schedule()
    new_schedule.group = old_group
    new_schedule.set_interrupts(old_interrupts)
    if old_records then new_schedule.set_records(old_records) end
    new_schedule.go_to_station(old_current)
    new_schedule.set_stopped(true)

    return new_id
end

---Moves a train a [distance] in [direction]
---@param self RSAD.Controller
---@param train LuaTrain
---@param distance integer
---@param direction defines.rail_direction
---@return AsyncAwait|number
function rsad_controller.move_train(self, train, distance, direction)
    local train_end = ((direction == defines.rail_direction.front) and train.front_end) or train.back_end
    local segment_end = train_end.make_copy()
    segment_end.move_to_segment_end()
    if not segment_end.move_forward(defines.rail_connection_direction.straight) then if not segment_end.move_forward(defines.rail_connection_direction.right) then segment_end.move_forward(defines.rail_connection_direction.left) end end
    segment_end.move_to_segment_end()
    --segment_end.flip_direction()
    local path_distance = 0
    if train_end.rail ~= segment_end.rail then
        --local path = game.train_manager.request_train_path({starts = {{rail = train_end.rail, direction = train_end.direction, allow_path_within_segment = true}}, goals = {segment_end}, shortest_path = true})
        local path = game.train_manager.request_train_path({train = train, goals = {segment_end}, shortest_path = true})
        if path.found_path then 
            path_distance = path_distance + path.total_length
        end
    end
    
    segment_end.flip_direction()
    if not segment_end.move_forward(defines.rail_connection_direction.straight) then if not segment_end.move_forward(defines.rail_connection_direction.right) then segment_end.move_forward(defines.rail_connection_direction.left) end end
    local segment_rail = segment_end.rail
    while segment_rail and path_distance < distance do
        path_distance = path_distance + segment_rail.get_rail_segment_length()
        segment_end.move_to_segment_end()
        if not segment_end.move_forward(defines.rail_connection_direction.straight) then if not segment_end.move_forward(defines.rail_connection_direction.right) then segment_end.move_forward(defines.rail_connection_direction.left) end end
        segment_rail = segment_end.rail
    end
    if not segment_rail or path_distance <= 0 then 
        log({"", "Could not find a viable movement path for train [" .. train.id .. "]."}) 
        for _, p in pairs(game.connected_players) do p.add_alert(train.front_stock, defines.alert_type.train_no_path) end
        return -1 
    end

    local lua_schedule = train.get_schedule()
    lua_schedule.add_record({index = {schedule_index = 1}, temporary = true, rail = segment_rail, wait_conditions = {{type = "time", ticks = 2}}})
    --local current = 
    lua_schedule.go_to_station(1)

    local await = self.scheduler:move_train_by_distance(train, distance)
    return await
end