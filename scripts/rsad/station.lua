require("scripts.defines")

local translation_id = nil
local translated_entity = nil

---@class StationData
---@field public type rsad_station_type?
---@field public network SignalID?
---@field public item SignalID?
---@field public subtype uint?

---@see create_rsad_station
---@class RSADStation
---@field public unit_number uint
---                                    success  data        
---@field public data fun(self: self): boolean, StationData?
---                                                         success
---@field public update fun(self: self, new_data: StationData): boolean
---
---@field public decommision fun(self: self)

---@param info_string string
---@return uint subtype
local function unpack_station_info(info_string)
    --- Layout: Station Type | Station Network | Station Item | packed_bytes_as(subtype)
    local packed_end, packed_start = info_string:find("|", -1, true)
    if not packed_end or not packed_start then return 0 end

    local packed_info = info_string:sub(packed_start, packed_end)
    local subtype = packed_info:byte(1)

    return subtype
end

---@param type rsad_station_type|string
---@param network SignalID|string
---@param item SignalID|string
---@param subtype uint
---@return string, LocalisedString
local function pack_station_info(type, network, item, subtype)
    ---                 Layout: Station Type | Station Network | Station Item | packed_bytes_as(subtype)
    local description = "station-" .. type --[[@as string]] .. " | " .. network.name or network .. " | " .. item.name or item .. " | "
    local packed_info = string.char(subtype)
    return description .. packed_info,
     {"", {"station-" .. type --[[@as string]] .. " | "}, {network.name or network .. " | "}, {item.name or item .. " | "}, packed_info}
end

---@param event EventData.on_string_translated
local function on_translate_description(event)
    if not translated_entity or not translation_id then 
        script.on_event(defines.events.on_string_translated, nil)
        return
    end
    if event.id == translation_id and event.translated then
        script.on_event(defines.events.on_string_translated, nil)
        translated_entity.combinator_description = event.localised_string
    end
end

---@param station RSADStation
---@return boolean success, StationData? data
local function get_station_data(station)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    local param = control.parameters

    local data = {
        type = param.operation --[[@as rsad_station_type]],
        network = param.first_signal,
        item = param.second_signal,
        subtype = unpack_station_info(station_entity.combinator_description)
    } --[[@type StationData]]

    return true, data
end

---@param station RSADStation
---@param new_data StationData
---@return boolean success
local function update_station_data(station, new_data)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    local params = control.parameters
    local type, network, item = new_data.type or params.operation, new_data.network or params.first_signal, new_data.item or params.second_signal

    local needs_unpacked_update = type ~= params.operation or network ~= params.first_signal or item ~= params.second_signal

    if not needs_unpacked_update and not new_data.subtype then return true end

    if type then
        ---@cast type string
        params.operation = type
    end
    if network then
        params.first_signal = network
    end
    if item then
        params.second_signal = item
    end

    local old_subtype = unpack_station_info(station_entity.combinator_description)
    local subtype = new_data.subtype or old_subtype
    if subtype == old_subtype and not needs_unpacked_update then return true end
    station_entity.combinator_description, localised_description = pack_station_info(type or "Not Assigned", network or "Not Connected", item or "No Item", subtype or 0)
    if game.player then
        translation_id = game.player.request_translation(localised_description)
        if translation_id then
            translated_entity = station_entity
            script.on_event(defines.events.on_string_translated, on_translate_description)
        end
    end

    control.parameters = params
    return true
end

local function decommision(station)
    local station_entity = game.get_entity_by_unit_number(station.unit_number)
    if not station_entity then return false end

    local control = station_entity.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    local params = control.parameters

    params.first_signal = nil

    control.parameters = params
end

---Creates a new RSADStation object
---@param entity LuaEntity
---@return RSADStation station
function create_rsad_station(entity)
    local station = {
        unit_number = entity.unit_number,
        data = get_station_data,
        update = update_station_data,
        decommision = decommision
    } --[[@type RSADStation]]
    
    return station
end