require("scripts.defines")

---@class RSAD.Actions
RSAD_Actions = {}

---@class (exact) TrainAlignment
---@field public from "locomotive"|"wagon"
---@field public direction defines.rail_direction
---@field public offset integer

---@class RSAD.Actions.Action
---@field public action string
---@field public params ...?

---@class RSAD.Actions.Scope
---@field public actions table<integer, RSAD.Actions.Action>
---@field public on_complete RSAD.Actions.Scope?
local working_set = nil --[[@type RSAD.Actions.Scope?]]
---@class RSAD.Actions.Set
---@field public train integer
---@field public scope RSAD.Actions.Scope
local open_set = nil --[[@type RSAD.Actions.Set?]]

---Opens a set for edits. Following RSAD_Actions calls will modify the opened set
function RSAD_Actions.open_set(train, controller)
    assert(open_set == nil, "Cannot open multiple RSAD.Actions.Set's!")
    open_set = { train = train.id, scope = { actions = {} }}
    working_set = open_set.scope --[[@as RSAD.Actions.Scope?]]
end

---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param wagon_count integer --Decouple this number of wagons from the train starting from the backmost locomotive if include_locomotives is false
---@param include_locomotives boolean
---@return int new_train_id
function RSAD_Actions.exec_decouple(train, controller, scope, wagon_count, include_locomotives)

end
---Decouple wagons from train
---@param wagon_count integer? --Decouple this number of wagons from the train starting from the backmost locomotive if include_locomotives is false
---@param include_locomotives boolean?
function RSAD_Actions.decouple(wagon_count, include_locomotives)
    assert(working_set ~= nil, "No open RSAD.Actions.Set!")
    ---@type RSAD.Actions.Action
    local action = {
        action = RSAD_Actions.Map[RSAD_Actions.decouple],
        params = wagon_count, include_locomotives
    }
    table.insert(working_set.actions, action)
end


---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param train_end defines.rail_direction --Train end to couple to
---@return int new_train_id
function RSAD_Actions.exec_couple(train, controller, scope, train_end)
    return controller:couple_direction(train, train_end)
end
---@param train_end defines.rail_direction? --Train end to couple to
function RSAD_Actions.couple(train_end)
    assert(working_set ~= nil, "No open RSAD.Actions.Set!")
    ---@type RSAD.Actions.Action
    local action = {
        action = RSAD_Actions.Map[RSAD_Actions.couple],
        params = train_end
    }
    table.insert(working_set.actions, action)
end

---@package
---@param train LuaTrain
---@param controller RSAD.Controller
---@param scope RSAD.Actions.Scope
---@param alignment TrainAlignment
---@return AsyncAwait<RSAD.Actions.Scope>
function RSAD_Actions.exec_align(train, controller, scope, alignment)
    
    local await = { scope = scope, complete = false } --[[@type AsyncAwait<RSAD.Actions.Scope>]]
    return await
end
---Align train to station
---@param alignment TrainAlignment
function RSAD_Actions.align_to_segment(alignment)
    assert(working_set ~= nil, "No open RSAD.Actions.Set!")
    ---@type RSAD.Actions.Action
    local action = {
        action = RSAD_Actions.Map[RSAD_Actions.couple],
        params = alignment
    }
    table.insert(working_set.actions, action)
end

---
---@nodiscard
---@return RSAD.Actions.Set
function RSAD_Actions.close_set()
    assert(open_set ~= nil, "Trying to close a non-open RSAD.Actions.Set!")
    local open = open_set
    open_set = nil
    return open
end

---@async
---@param set RSAD.Actions.Set
---@param controller RSAD.Controller
---@return boolean, AsyncAwait?
function RSAD_Actions.start_actionset_execution(set, controller)
    local train = game.train_manager.get_train_by_id(set.train)
    if not train then return false end

    for _, action in pairs(set.scope.actions) do
        local old_train_id = train.id
        local result = RSAD_Actions[action.action](train, controller, set.scope, action.params)
        if type(result) == "number" then
            train = game.train_manager.get_train_by_id(result)
            if not train then return false end
            local yard = controller.train_yards[controller.shunter_networks[old_train_id] or ""]
            if yard then yard:redefine_shunter(old_train_id, result) end
        else
            return true, result
        end
    end
    return true
end

---@async
---@param context AsyncAwait<RSAD.Actions.Scope>
---@param train LuaTrain
---@param controller RSAD.Controller
---@return boolean, AsyncAwait?
function RSAD_Actions.continue_actionset_execution(context, train, controller)
    for _, action in pairs(context.scope.actions) do
        local old_train_id = train.id
        local result = RSAD_Actions[action.action](train, controller, action.params)
        if type(result) == "number" then
            train = game.train_manager.get_train_by_id(result) --[[@as LuaTrain]]
            if not train then return false end
            local yard = controller.train_yards[controller.shunter_networks[old_train_id] or ""]
            if yard then yard:redefine_shunter(old_train_id, result) end
        else
            return true, result
        end
    end

    return true
end

---@type table<fun(train:LuaTrain, controller:RSAD.Controller, scope:RSAD.Actions.Scope, ...):int|AsyncAwait, string>
RSAD_Actions.Map = {
    [RSAD_Actions.decouple] = "exec_decouple",
    [RSAD_Actions.couple] = "exec_couple",
    [RSAD_Actions.align_to_segment] = "exec_align",
}

return RSAD_Actions