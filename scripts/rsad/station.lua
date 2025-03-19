require("scripts.defines")
require("scripts.rsad.util")

---@class RSAD.Station.Data
---@field public type rsad_station_type?
---@field public network SignalID?
---@field public item SignalID?
---@field public subinfo uint?
---@field public train_limit uint?
---@field public reversed_shunting boolean?

---@see create_rsad_station
---
---@class RSAD.Station
---@field public unit_number uint
---@field public assignments uint -- Number of assigned trains to this station
---@field public parked_train uint? -- train ID that is currently parked at this station. Wagons without a locomotive also have a train ID. nil if none

---@param constant int
---@return uint type, uint subinfo, boolean reversed
local function unpack_station_constant(constant)
    --- Layout: Station Type | Reversed Shunting | Station Subinfo |
    local type = bit32.extract(constant, STATION_TYPE_ID, STATION_TYPE_ID_WIDTH)
    local subinfo = bit32.extract(constant, STATION_SUBINFO, STATION_SUBINFO_WIDTH)
    local reversed = bit32.extract(constant, SHUNTING_DIRECTION, SHUNTING_DIRECTION_WIDTH) == 1
    return type, subinfo, reversed
end

---@param type rsad_station_type|uint
---@param subinfo uint
---@param reversed boolean
---@return uint
local function pack_station_constant(type, subinfo, reversed)
    return bit32.bor(type, bit32.lshift(reversed and 1 or 0, STATION_TYPE_ID_WIDTH), bit32.lshift(subinfo, STATION_TYPE_ID_WIDTH + SHUNTING_DIRECTION_WIDTH))
end

---@param station RSAD.Station
---@return boolean success, LuaEntity station_entity, RSAD.Station.Data data
function get_station_data(station)
    local station_entity = station and game.get_entity_by_unit_number(station.unit_number)
---@diagnostic disable-next-line: return-type-mismatch
    if not station_entity or not station_entity.valid then return false, nil, nil end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]

---@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.53
    local type, subinfo, reversed = unpack_station_constant(control.circuit_condition.constant)

    ---@type RSAD.Station.Data
    local data = {
        type = type --[[@as rsad_station_type]],
        network = control.stopped_train_signal,
        item = control.priority_signal,
        subinfo = subinfo,
        train_limit = station_entity.trains_limit,
        reversed_shunting = reversed
    }

    return true, station_entity, data
end

---@param station RSAD.Station
---@param new_data RSAD.Station.Data
---@return boolean success
function update_station_data(station, new_data)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity or not station_entity.valid then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    ------@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.35
    local old_type, old_subinfo, old_reversed = unpack_station_constant(control.circuit_condition.constant or 1)
    local type, network, item, subinfo, train_limit, reversed =
        new_data.type or old_type, new_data.network or control.stopped_train_signal,
        new_data.item or control.priority_signal, new_data.subinfo or old_subinfo,
        new_data.train_limit or station_entity.trains_limit, new_data.reversed_shunting or old_reversed

    local needs_update = type ~= old_type or network ~= control.stopped_train_signal or
                         item ~= control.priority_signal or subinfo ~= old_subinfo or
                         train_limit ~= station_entity.trains_limit or reversed ~= old_reversed

    if not needs_update then return true end

    control.stopped_train_signal = network
    control.priority_signal = item
    if train_limit == 0 then station_entity.trains_limit = nil else station_entity.trains_limit = train_limit end

    local circuit = control.circuit_condition
    ------@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = pack_station_constant(type, subinfo, reversed)
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
---@return RSAD.Station station
function create_rsad_station(entity)
    entity.trains_limit = 1
    local station = {
        unit_number = entity.unit_number,
        assignments = 0,
        parked_train = nil
    } --[[@type RSAD.Station]]
    
    return station
end