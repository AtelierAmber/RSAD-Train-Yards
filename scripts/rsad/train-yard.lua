---@type flib.Queue
queue = require("__flib__.queue")
require("scripts.defines")
require("scripts.rsad.station")

local next = next -- Assign local table next for indexing speed

---@see create_train_yard
---@class TrainYard
---@field public network SignalID
---@field public rsad_station_type.shunting_depot {[uint]: RSADStation} 
---@field public rsad_station_type.turnabout {uint: [shunting_stage]}
---@field public rsad_station_type.import_staging {[uint]: RSADStation}
---@field public rsad_station_type.import {[string]: {[uint]: RSADStation}} -- Maps item to RSADStations
---@field public rsad_station_type.request {[uint]: string} --- Maps RSADStation to their item request
---@field public rsad_station_type.empty_staging {[uint]: RSADStation}
---@field public rsad_station_type.empty_pickup {[uint]: RSADStation}
---Functions
---@field public add_or_update_station fun(self: self, station: RSADStation): boolean --- Adds the station to the relevant array. Returns success
---@field public remove_station fun(self: self, station: RSADStation) --- Removes the station from yard

--- TODO: Make custom schedules possible

--- Removes the station if it exists from all registers
---@param yard TrainYard
---@param station RSADStation
local function remove_station(yard, station)
    yard[rsad_station_type.shunting_depot][station.unit_number] = nil
    yard[rsad_station_type.turnabout][station.unit_number] = nil
    yard[rsad_station_type.import_staging][station.unit_number] = nil
    for i,v in pairs(yard[rsad_station_type.import]) do
        v[station] = nil
        if next(v) then
            yard[rsad_station_type.import][i] = nil
        end
    end
    yard[rsad_station_type.request][station.unit_number] = nil
    yard[rsad_station_type.empty_staging][station.unit_number] = nil
    yard[rsad_station_type.empty_pickup][station.unit_number] = nil
end

--- Adds the station to the relevant array or modifies an existing station to a new designation
---@param yard TrainYard
---@param station RSADStation
---@return boolean success
local function add_or_update_station(yard, station)
    local success, data = station:data()
    yard:remove_station(station)

    if success or not data or not data.type then return false end

    if data.type == rsad_station_type.turnabout then
        yard[data.type][station.unit_number] = data.subtype
    elseif data.type == rsad_station_type.import and data.item and data.item.name then
        yard[data.type][data.item.name][station.unit_number] = station
    elseif data.type == rsad_station_type.request and data.item and data.item.name then
        yard[data.type][station.unit_number] = data.item.name
    else
        yard[data.type][station.unit_number] = station
    end

    station:update({network = yard.network})

    return true
end

---Creates a new TrainYard object
---@param network SignalID
---@return TrainYard
function create_train_yard(network)
    local yard = {
        network = network,
        [rsad_station_type.shunting_depot] = {},
        [rsad_station_type.turnabout] = {}, -- maps the shunting_stage to the station
        [rsad_station_type.import_staging] = {}, -- list of staging for imports. If included the imports will be sorted from here into the import stations. It's best to also include a bypass for trains with a single import
        [rsad_station_type.import] = {}, -- list of all import stations and their item. Can only be assigned to a single item
        [rsad_station_type.request] = {}, -- list of all request stations and their requested item. Can only be assigned to a single item
        [rsad_station_type.empty_staging] = {}, -- staging for empty wagons
        [rsad_station_type.empty_pickup] = {}, -- staging for empty wagons

        -- Functions
        add_or_update_station = add_or_update_station,
        remove_station = remove_station
    } --[[@type TrainYard]]
    return yard
end