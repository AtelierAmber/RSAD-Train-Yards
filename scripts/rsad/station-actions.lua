require("scripts.defines")
require("scripts.rsad.util")
flib_table = require("__flib__.table") --[[@type flib_table]]

---@class RSAD.Actions
RSAD_Actions = {}

---@class (exact) TrainAlignment
---@field public ignore_locomotives boolean --Whether to ignore logomotives when determining [offset_num] 
---@field public move_direction defines.rail_direction|RSAD.Actions.RuntimeParam --Movement direction of the train in relation to the train it is on
---@field public align_side defines.rail_direction|RSAD.Actions.RuntimeParam --Side of the carriage that is aligned to the segment
---@field public offset_from defines.rail_direction|RSAD.Actions.RuntimeParam --End of the train to start [offset_num] from
---@field public offset_num integer|RSAD.Actions.RuntimeParam --Carriage offset in opposite direction to [direction]
---@field public continue_no_alignment boolean? --Defaults to false. If false, will cancel the movement action when [offset_num] is greater than carriage count or wagon count if [ignore_locomotives] is true

---@enum RSAD.Actions.RuntimeParamType
RuntimeParamType = {
    starting = {
        train = {
            locomotive_count = "train.starting.locomotive_count",
            carriage_count = "train.starting.carriage_count",
            wagon_count = "train.starting.wagon_count",
            pickup_info = "train.starting.pickup_info", --Pickup info defined in a shunter if the train is a shunter
            arrival_direction = "train.starting.arrival_direction", --Defined as the train_end that stopped closest to the station
            reversed_direction = "train.starting.reversed_direction", --Defined as opposite to arrival_direction
        }
    },
    current = {
        train = {
            wagon_count = "train.current.wagon_count",
        }
    }
}

---@class RSAD.Actions.RuntimeParam
---@field public runtime boolean
---@field public variable RSAD.Actions.RuntimeParamType|string

---@class RSAD.Actions.Action
---@field public action string
---@field public params table<nil|string|number|boolean|table, nil|string|number|boolean|table|RSAD.Actions.RuntimeParam>

---@class RSAD.Actions.Scope
---@field public actions table<integer, RSAD.Actions.Action>
---@field public next RSAD.Actions.Scope?
---@field public initial_state table<RSAD.Actions.RuntimeParamType, any>? --Starting state when the set this scope is in is executed
---@field public station RSAD.Station?
local working_scope = nil --[[@type RSAD.Actions.Scope?]]

---@class RSAD.Actions.Set  
---@field public scope RSAD.Actions.Scope
local open_set = nil --[[@type RSAD.Actions.Set?]]

---Opens a set for edits. Following RSAD_Actions calls will modify the opened set
function RSAD_Actions.open_set()
    assert(open_set == nil, "Cannot open multiple RSAD.Actions.Set's!")
    open_set = { scope = { actions = {} }}
    working_scope = open_set.scope --[[@as RSAD.Actions.Scope?]]
end

--#region Action Defs

---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param params {wagon_count:integer, ignore_locomotive:boolean, direction:defines.rail_direction}
---@return int new_train_id
function RSAD_Actions.exec_decouple(train, controller, scope, params)
    if not RSAD_Actions.resolve_runtime_params(train, controller, scope, table) then return -1 end
    local carriages = train.carriages
    local decouple_at = nil
    if params.ignore_locomotive then
        decouple_at = carriages[math.min(#carriages, params.wagon_count)]
    else
        if params.direction == defines.rail_direction.front then
            for i = 1, #carriages, 1 do
                local carriage = carriages[i]
                if not decouple_at and carriage.type == "locomotive" then
                    decouple_at = carriages[math.max(0, i-(params.wagon_count))]
                end
            end
        else
            for i = #carriages, 1, -1 do
                local carriage = carriages[i]
                if not decouple_at and carriage.type == "locomotive" then
                    decouple_at = carriages[math.min(#carriages, i+(params.wagon_count))]
                end
            end
        end
    end
    if not decouple_at then log({"", "Could not decouple " .. params.wagon_count .. " carriage offset from train with " .. #carriages .. " carriages from rear" .. ((params.ignore_locomotive and " locomotive") or ".")}) return -1 end
    local direction = params.direction
    return controller:decouple_at(train, decouple_at, direction, false)
end
---Decouple wagons from train
---@param wagon_count integer|RSAD.Actions.RuntimeParam --Decouple offset this number of wagons from the train starting from the backmost locomotive if 
---ignore_locomotive is false or backmost carriage if ignore_locomotive is true or no locomotives; going to the back of the train
---@param ignore_locomotive boolean|RSAD.Actions.RuntimeParam
---@param offset_direction defines.rail_direction|RSAD.Actions.RuntimeParam
function RSAD_Actions.decouple(wagon_count, ignore_locomotive, offset_direction)
    assert(working_scope ~= nil, "No open RSAD.Actions.Set!")
    ---@type RSAD.Actions.Action
    local action = {
        action = RSAD_Actions.Map[RSAD_Actions.decouple],
        params = {wagon_count = wagon_count, ignore_locomotive = ignore_locomotive, direction = offset_direction}
    }
    table.insert(working_scope.actions, action)
end

---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param params {train_end: defines.rail_direction}
---train_end Train end to couple to 
---@return number new_train_id
function RSAD_Actions.exec_couple(train, controller, scope, params)
    return controller:couple_direction(train, params.train_end)
end
---@param train_end defines.rail_direction|RSAD.Actions.RuntimeParam --Train end to couple to
function RSAD_Actions.couple(train_end)
    assert(working_scope ~= nil, "No open RSAD.Actions.Set!")
    ---@type RSAD.Actions.Action
    local action = {
        action = RSAD_Actions.Map[RSAD_Actions.couple],
        params = {train_end = train_end}
    }
    table.insert(working_scope.actions, action)
end

---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param alignment TrainAlignment
---@return AsyncAwait|number
function RSAD_Actions.exec_align(train, controller, scope, alignment)
    if not RSAD_Actions.resolve_runtime_params(train, controller, scope, table) then return -1 end
    if not alignment.continue_no_alignment and not alignment.ignore_locomotives and (#train.carriages <= alignment.offset_num) then return train.id end
    local travel_distance = 0
    local carriage = (alignment.offset_from == defines.rail_direction.back and train.back_stock) or train.front_stock
    local seek_dir = (alignment.offset_from == defines.rail_direction.back and defines.rail_direction.front) or defines.rail_direction.back
    while alignment.ignore_locomotives and carriage and carriage.type == "locomotive" do
        carriage = carriage.get_connected_rolling_stock((carriage.is_headed_to_trains_front and seek_dir) or ((seek_dir == defines.rail_direction.front and defines.rail_direction.back) or defines.rail_direction.front))
    end
    local next_carriage = carriage
    for i = 1, alignment.offset_num, 1 do
        carriage = next_carriage
        next_carriage = carriage and carriage.get_connected_rolling_stock((carriage.is_headed_to_trains_front and seek_dir) or ((seek_dir == defines.rail_direction.front and defines.rail_direction.back) or defines.rail_direction.front))
        local distance = (carriage and carriage.prototype.joint_distance + carriage.prototype.connection_distance) or 0
        travel_distance = travel_distance + distance
        if not next_carriage then break end
    end
    if not alignment.continue_no_alignment and next_carriage == nil then return train.id end
    if alignment.align_side == alignment.offset_from then --Need to remove connection_distance
        travel_distance = travel_distance - ((carriage and (carriage.prototype.connection_distance/2)) or 0)
    end
    local await = controller:move_train(train, travel_distance, alignment.move_direction --[[@as defines.rail_direction]])
    if type(await) == "number" then
        return await
    end
    await.scope = scope.next
    return await
end
---Align train to station
---@param alignment TrainAlignment|RSAD.Actions.RuntimeParam
function RSAD_Actions.align_to_segment(alignment)
    assert(working_scope ~= nil, "No open RSAD.Actions.Set!")
    ---@type RSAD.Actions.Action
    local action = {
        action = RSAD_Actions.Map[RSAD_Actions.align_to_segment],
        params = alignment
    }
    table.insert(working_scope.actions, action)
    working_scope.next = { actions = {} }
    working_scope = working_scope.next
end

---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param params {}
---@return number new_train_id
function RSAD_Actions.exec_define_shunter(train, controller, scope, params)
    if not scope.station then return -1 end
    local success, entity, data = get_station_data(scope.station)
    local yard = controller:get_train_yard_or_nil(data.network)
    if not yard then return -1 end
    controller:assign_shunter(train.id, yard)
    return train.id
end
---Defines arriving train as a shunter
function RSAD_Actions.define_as_shunter()
    assert(working_scope ~= nil, "No open RSAD.Actions.Set!")
    ---@type RSAD.Actions.Action
    local action = {
        action = RSAD_Actions.Map[RSAD_Actions.define_as_shunter],
        params = {}
    }
    table.insert(working_scope.actions, action)
end

---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param params {}
---@return number new_train_id
function RSAD_Actions.exec_leave(train, controller, scope, params)
    if scope.station.parked_train == train.id then controller:free_parked_station(scope.station) end
    local schedule = train.schedule
    local current = schedule and schedule.current
    if schedule and current == #schedule.records then
        local network = controller.shunter_networks[train.id]
        local yard = network and controller.train_yards[network]
        if yard then
            controller.scheduler:return_shunter(train, yard)
            train.manual_mode = false
            return train.id
        end
    end
    train.go_to_station((current or 0) + 1)
    train.manual_mode = false
    return train.id
end
function RSAD_Actions.leave_station()
    assert(working_scope ~= nil, "No open RSAD.Actions.Set!")
    ---@type RSAD.Actions.Action
    local action = {
        action = RSAD_Actions.Map[RSAD_Actions.leave_station],
        params = {}
    }
    table.insert(working_scope.actions, action)
end

--#endregion

---
---@nodiscard
---@return RSAD.Actions.Set
function RSAD_Actions.close_set()
    assert(open_set ~= nil, "Trying to close a non-open RSAD.Actions.Set!")
    local open = open_set
    open_set = nil
    return open
end

---@type table<RSAD.Actions.RuntimeParamType, fun(train:LuaTrain, controller:RSAD.Controller, station:RSAD.Station):any>
local runtime_param_handlers = {
    [RuntimeParamType.starting.train.locomotive_count] = function (train, controller, station)
        local locomotives = (train --[[@as LuaTrain]]).locomotives
        return table_size(locomotives.front_movers) + table_size(locomotives.back_movers)
    end,
    [RuntimeParamType.starting.train.carriage_count] = function (train, controller, station)
        local carriages = (train --[[@as LuaTrain]]).carriages
        return #carriages
    end,
    [RuntimeParamType.starting.train.wagon_count] = function (train, controller, station)
        local locomotives = (train --[[@as LuaTrain]]).locomotives
        local locomotive_count = table_size(locomotives.front_movers) + table_size(locomotives.back_movers)
        local carriages = (train --[[@as LuaTrain]]).carriages
        return #carriages - locomotive_count
    end,
    [RuntimeParamType.starting.train.pickup_info] = function (train, controller, station)
        local network = (controller --[[@as RSAD.Controller]]).shunter_networks[(train --[[@as LuaTrain]]).id]
        local yard = network and ((controller --[[@as RSAD.Controller]]).train_yards[network])
        local shunter = yard and yard.shunter_trains[(train --[[@as LuaTrain]]).id]
        return shunter and shunter.pickup_info
    end,
    [RuntimeParamType.starting.train.arrival_direction] = function (train, controller, station)
        local entity = game.get_entity_by_unit_number((station --[[@as RSAD.Station]]).unit_number)
        if not entity or not entity.valid then
            local front = (train --[[@as LuaTrain]]).front_end
            local next_rail = front.make_copy()
            local moved = false
            if not next_rail.move_forward(defines.rail_connection_direction.straight) then if not next_rail.move_forward(defines.rail_connection_direction.right) then moved = next_rail.move_forward(defines.rail_connection_direction.left) else moved = true end else moved = true end
            if moved and front.rail.is_rail_in_same_rail_segment_as(next_rail.rail) then
                return front.direction
            end
            return (train --[[@as LuaTrain]]).back_end.direction
        end
        return select(2, get_front_stock(train, entity))
    end,
    [RuntimeParamType.starting.train.reversed_direction] = function (train, controller, station)
        local entity = game.get_entity_by_unit_number((station --[[@as RSAD.Station]]).unit_number)
        if not entity or not entity.valid then
            local front = (train --[[@as LuaTrain]]).front_end
            local next_rail = front.make_copy()
            local moved = false
            if not next_rail.move_forward(defines.rail_connection_direction.straight) then if not next_rail.move_forward(defines.rail_connection_direction.right) then moved = next_rail.move_forward(defines.rail_connection_direction.left) else moved = true end else moved = true end
            if moved and front.rail.is_rail_in_same_rail_segment_as(next_rail.rail) then
                return (train --[[@as LuaTrain]]).back_end.direction
            end
            return front.direction
        end
        return (select(2, get_front_stock(train, entity)) == defines.rail_direction.front and defines.rail_direction.back) or defines.rail_direction.front
    end,
    [RuntimeParamType.current.train.wagon_count] = function (train, controller, station)
        local locomotives = (train --[[@as LuaTrain]]).locomotives
        local locomotive_count = table_size(locomotives.front_movers) + table_size(locomotives.back_movers)
        local carriages = (train --[[@as LuaTrain]]).carriages
        return #carriages - locomotive_count
    end,
}
---Resolve incoming runtime param type
---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param station RSAD.Station?
---@param paramType RSAD.Actions.RuntimeParamType|string --Type of param
function RSAD_Actions.resolve_runtime_param(train, controller, station, paramType)
    local handler = runtime_param_handlers[paramType]
    return handler and handler(train, controller, station)
end

---Resolves all fields of given [table] if they are RSAD.Actions.RuntimeParams
---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param table table<any, any|RSAD.Actions.RuntimeParamType>
---@return boolean success
function RSAD_Actions.resolve_runtime_params(train, controller, scope, table)
    for name, param in pairs(table) do
        if type(param) == "table" and param.runtime then
            local value = scope.initial_state[param.variable]
            if value == nil then
                value = RSAD_Actions.resolve_runtime_param(train, controller, scope.station, param.variable)
            end
            if value == nil then log({"", "Could not resolve runtime param type [" .. param.variable .. "] for train [" .. ((train and train.id) or "nil") .. "] and station [" .. ((scope.station and scope.station.unit_number) or "none") .. "]"}) return false end
            table[name] = value
        end
    end
    return true
end

---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param station RSAD.Station?
---@return table<RSAD.Actions.RuntimeParamType, any>
function RSAD_Actions.initialize_starting_state(train, controller, station)
    local state = {}
    for _, category in pairs(RuntimeParamType.starting) do
        for _, paramType in pairs(category) do
            local value = RSAD_Actions.resolve_runtime_param(train, controller, station, paramType)
            state[paramType] = value
        end
    end
    return state
end

---@async
---@param train LuaTrain
---@param set RSAD.Actions.Set
---@param controller RSAD.Controller
---@param station RSAD.Station? --If action set is coming from a station this should be positive. RSAD.Actions.RuntimeParams that access a station when no station is present will return nil
---@return boolean, LuaTrain?, AsyncAwait?
function RSAD_Actions.start_actionset_execution(train, set, controller, station)
    local state = RSAD_Actions.initialize_starting_state(train, controller, station)
    set.scope.initial_state = state
    set.scope.station = station
    for _, action in pairs(set.scope.actions) do
        local old_train_id = train.id
        if not RSAD_Actions.resolve_runtime_params(train, controller, set.scope, action.params) then return false, train end
        local result = RSAD_Actions[action.action](train, controller, set.scope, action.params)
        if type(result) == "number" then
            if result < 0 then log({"", "Error occured when executing action set at train [" .. (train and train.valid and train.id) or "unknown" .. "]"})return false, train end
            ---@diagnostic disable-next-line: cast-local-type
            train = game.train_manager.get_train_by_id(result)
            if not train then return false, train end
            controller:redefine_shunter(old_train_id, result)
        else
            result.scope.initial_state = set.scope.initial_state
            result.scope.station = station
            return true, train, result
        end
    end
    return true, train
end

---@async
---@param context AsyncAwait
---@param train LuaTrain
---@param controller RSAD.Controller
---@return boolean, LuaTrain?, AsyncAwait?
function RSAD_Actions.continue_actionset_execution(context, train, controller)
    if context.scope == nil then return true, train end
    for _, action in pairs(context.scope.actions) do
        local old_train_id = train.id
        if not RSAD_Actions.resolve_runtime_params(train, controller, context.scope, action.params) then return false, train end
        local result = RSAD_Actions[action.action](train, controller, context.scope, action.params)
        if type(result) == "number" then
            if result < 0 then log({"", "Error occured when executing action set at train [" .. (train and train.valid and train.id) or "unknown" .. "]"})return false, train end
            ---@diagnostic disable-next-line: cast-local-type
            train = game.train_manager.get_train_by_id(result)
            if not train then return false, train end
            controller:redefine_shunter(old_train_id, result)
        else
            result.scope.initial_state = context.scope.initial_state
            result.scope.station = context.scope.station
            return true, result
        end
    end

    return true, train
end

---@type table<fun(train:LuaTrain, controller:RSAD.Controller, scope:RSAD.Actions.Scope, ...):number|AsyncAwait, string>
RSAD_Actions.Map = {
    [RSAD_Actions.decouple] = "exec_decouple",
    [RSAD_Actions.couple] = "exec_couple",
    [RSAD_Actions.align_to_segment] = "exec_align",
    [RSAD_Actions.define_as_shunter] = "exec_define_shunter",
    [RSAD_Actions.leave_station] = "exec_leave",
}

return RSAD_Actions