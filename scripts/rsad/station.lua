require("scripts.defines")
require("scripts.rsad.util")

---@class StationData
---@field public type rsad_station_type?
---@field public network SignalID?
---@field public item SignalID?
---@field public subtype uint?
---@field public train_limit uint?
---@field public reversed_shunting boolean?

---@see create_rsad_station
---
---@class RSADStation
---@field public unit_number uint
---@field public assignments uint -- Number of assigned trains to this station
---@field public parked_train uint? -- train ID that is currently parked at this station. Wagons without a locomotive also have a train ID. nil if none

---                                    success  data        
-- ---@field public data fun(self: self): boolean, StationData?
-- ---                                                         success
-- ---@field public update fun(self: self, new_data: StationData): boolean
-- ---
-- ---@field public decommision fun(self: self)

---@param constant int
---@return uint type, uint subtype, boolean reversed
local function unpack_station_constant(constant)
    --- Layout: Station Type | Station Subtype | Reversed Shunting |
    local type = bit32.extract(constant, 0, 4)              -- 0000 0000 1111
    local subtype = bit32.extract(constant, 4, 4)           -- 0000 1111 0000
    local reversed = bit32.extract(constant, 8, 1) == 1     -- 0001 0000 0000
    return type, subtype, reversed
end

---@param type rsad_station_type|uint
---@param subtype uint
---@param reversed boolean
---@return uint
local function pack_station_constant(type, subtype, reversed)
    return bit32.bor(type, bit32.lshift(subtype, 4), bit32.lshift(reversed and 1 or 0, 5))
end

---@param station RSADStation
---@return boolean success, LuaEntity? station_entity, StationData? data
function get_station_data(station)
    local station_entity = station and game.get_entity_by_unit_number(station.unit_number)
    if not station_entity or not station_entity.valid then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]

---@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.53
    local type, subtype, reversed = unpack_station_constant(control.circuit_condition.constant)

    ---@type StationData
    local data = {
        type = type --[[@as rsad_station_type]],
        network = control.stopped_train_signal,
        item = control.priority_signal,
        subtype = subtype,
        train_limit = station_entity.trains_limit,
        reversed_shunting = reversed
    }

    return true, station_entity, data
end

---@param station RSADStation
---@param new_data StationData
---@return boolean success
function update_station_data(station, new_data)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity or not station_entity.valid then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    ---@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.35
    local old_type, old_subtype, old_reversed = unpack_station_constant(control.circuit_condition.constant or 1)
    local type, network, item, subtype, train_limit, reversed =
        new_data.type or old_type, new_data.network or control.stopped_train_signal,
        new_data.item or control.priority_signal, new_data.subtype or old_subtype,
        new_data.train_limit or station_entity.trains_limit, new_data.reversed_shunting or old_reversed

    local needs_update = type ~= old_type or network ~= control.stopped_train_signal or
                         item ~= control.priority_signal or subtype ~= old_subtype or
                         train_limit ~= station_entity.trains_limit or reversed ~= old_reversed

    if not needs_update then return true end

    control.stopped_train_signal = network
    control.priority_signal = item
    if train_limit == 0 then station_entity.trains_limit = nil else station_entity.trains_limit = train_limit end

    local circuit = control.circuit_condition
    ---@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = pack_station_constant(type, subtype, reversed)
    control.circuit_condition = circuit

    update_rsad_station_name(station_entity, control, type)

    return true
end

function decommision_station(station)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity or not station_entity.valid then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    control.stopped_train_signal = nil
end

---Creates a new RSADStation object
---@param entity LuaEntity
---@return RSADStation station
function create_rsad_station(entity)
    entity.trains_limit = 1
    local station = {
        unit_number = entity.unit_number,
        assignments = 0,
        parked_train = nil
    } --[[@type RSADStation]]
    
    return station
end