---@param entity LuaEntity
---@param control LuaTrainStopControlBehavior
---@param index uint
function update_rsad_station_name(entity, control, index)
    local network_name = "Unassigned"
    if control.stopped_train_signal and control.stopped_train_signal.name then
        network_name = (control.stopped_train_signal.type or "item")
        if network_name == "virtual" then
            network_name = network_name .. "-signal"
        end
        network_name = network_name .. "=" .. control.stopped_train_signal.name
    end
    local item_name = ""
    if control.priority_signal and (index == rsad_station_type.import or index == rsad_station_type.request) then 
        local type = (((not control.priority_signal.type and "item=") or (control.priority_signal.type == "fluid" and "fluid=")) or "virtual-signal=") --[[@as string]]
        item_name = "[" .. (control.priority_signal and (type .. control.priority_signal.name) or "No Item") .. "]"
    end
    local turnabout_phase_string = ""
    ---@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    local turnabout_phase = bit32.extract(control.circuit_condition.constant, STATION_SUBINFO, STATION_SUBINFO_WIDTH)
    if index == rsad_station_type.turnabout then
        turnabout_phase_string = rsad_stage_name[turnabout_phase] .. " "
    end
    entity.backer_name = "RSAD Controlled | [" .. network_name .. "] " .. turnabout_phase_string .. rsad_station_name[index] .. item_name
end

---comment
---@param signal SignalID?
---@return string? hash
function signal_hash(signal)
    local signal_type = signal and signal.type or "item-name" --[[@as string?]]
    if signal_type == "virtual" then signal_type = "virtual-signal" end
    return (signal_type and (signal and signal.name) and (signal_type .. "-name".. "." .. signal.name))
end

---@param p1 MapPosition
---@param p2 MapPosition
function position_distance(p1, p2)
    return math.sqrt((p2.x - p1.x)^2 + (p2.y-p1.y)^2)
end
---@param train LuaTrain
---@param station_entity LuaEntity
---@return LuaEntity, defines.rail_direction
function get_front_stock(train, station_entity)
    local front_dist = position_distance(train.front_stock.position, station_entity.position)
    local back_dist = position_distance(train.back_stock.position, station_entity.position)
    if front_dist < back_dist then return train.front_stock, defines.rail_direction.front end
    return train.back_stock, defines.rail_direction.back
end

---@param train LuaTrain
---@return LuaEntity entity, defines.rail_direction front_direction
function get_back_cargo(train)
    local back = train.carriages[#train.carriages].type ~= "locomotive"
    return (back and train.carriages[#train.carriages] or train.carriages[1]), (back and defines.rail_direction.front or defines.rail_direction.back)
end