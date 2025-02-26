require("scripts.defines")

---@class StationData
---@field public type rsad_station_type?
---@field public network SignalID?
---@field public item SignalID?
---@field public subtype uint?

---@see create_rsad_station
---@class RSADStation
---@field public unit_number uint
---@field public assignements uint -- Number of assigned trains to this station

---                                    success  data        
-- ---@field public data fun(self: self): boolean, StationData?
-- ---                                                         success
-- ---@field public update fun(self: self, new_data: StationData): boolean
-- ---
-- ---@field public decommision fun(self: self)

---@param constant int
---@return uint type, uint subtype
local function unpack_station_constant(constant)
    --- Layout: Station Type | Station Network | Station Item | packed_bytes_as(subtype)
    local type = bit32.extract(constant, 0, 4) -- 0000 1111
    local subtype = bit32.extract(constant, 4, 4) -- 1111 0000
    return type, subtype
end

---@param type rsad_station_type|string
---@param subtype uint
---@return uint
local function pack_station_constant(type, subtype)
    return bit32.bor(type, bit32.lshift(subtype, 4))
end

---@param station RSADStation
---@return boolean success, StationData? data
function get_station_data(station)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]

---@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.53
    local type, subtype = unpack_station_constant(control.circuit_condition.constant)

    local data = {
        type = type --[[@as rsad_station_type]],
        network = control.stopped_train_signal,
        item = control.priority_signal,
        subtype = subtype
    } --[[@type StationData]]

    return true, data
end

---@param station RSADStation
---@param new_data StationData
---@return boolean success
function update_station_data(station, new_data)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    ---@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.35
    local old_type, old_subtype = unpack_station_constant(control.circuit_condition.constant or 1)
    local type, network, item, subtype = new_data.type or old_type, new_data.network or control.stopped_train_signal, new_data.item or control.priority_signal, new_data.subtype or old_subtype

    local needs_update = type ~= old_type or network ~= control.stopped_train_signal or item ~= control.priority_signal or subtype ~= old_subtype

    if not needs_update then return true end

    control.stopped_train_signal = network
    control.priority_signal = item

    local circuit = control.circuit_condition
    ---@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = pack_station_constant(type, subtype)
    control.circuit_condition = circuit

    update_station_name(station_entity, control, type)

    -- local network_name = "Unassigned"
    -- if control.stopped_train_signal and control.stopped_train_signal.name then
    --     network_name = (control.stopped_train_signal.type or "item")
    --     if network_name == "virtual" then
    --         network_name = network_name .. "-signal"
    --     end
    --     network_name = network_name .. "=" .. control.stopped_train_signal.name
    -- end
    -- local item_name = ""
    -- if control.priority_signal and (type == rsad_station_type.import or type == rsad_station_type.request) then 
    --     item_name = "[" .. (("item=" .. control.priority_signal.name) or "No Item") .. "]"
    -- end
    -- station_entity.backer_name = "RSAD Controlled | [" .. network_name .. "] " .. rsad_station_name[type] .. item_name

    return true
end

function decommision_station(station)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    control.stopped_train_signal = nil
end

---Creates a new RSADStation object
---@param entity LuaEntity
---@return RSADStation station
function create_rsad_station(entity)
    local station = {
        unit_number = entity.unit_number,
        assignments = 0
    } --[[@type RSADStation]]
    

    return station
end