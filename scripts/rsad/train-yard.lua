require("scripts.defines")
require("scripts.rsad.station")

local next = next -- Assign local table next for indexing speed

---@class ShuntingData
---@field public current_stage rsad_shunting_stage
---@field public schedule TrainSchedule

---@see create_train_yard
---@class TrainYard
---@field public network SignalID
---@field public rsad_station_type.shunting_depot {[uint]: RSADStation} 
---@field public rsad_station_type.turnabout {[rsad_shunting_stage]: RSADStation}
---@field public rsad_station_type.import_staging {[uint]: RSADStation}
---@field public rsad_station_type.import {[string]: {[uint]: RSADStation}} -- Maps item to RSADStations
---@field public rsad_station_type.request {[uint]: string} --- Maps RSADStation to their item request
---@field public rsad_station_type.empty_staging {[uint]: RSADStation}
---@field public rsad_station_type.empty_pickup {[uint]: RSADStation}
---@field public shunter_trains {[uint]: ShuntingData} --- BOUND TO STORAGE
---Functions
---@field public add_or_update_station fun(self: self, station: RSADStation): boolean --- Adds the station to the relevant array. Returns success
---@field public remove_station fun(self: self, station: RSADStation) --- Removes the station from yard
---@field public is_empty fun(self: self): boolean --- Returns true if no stations exist in this yard
---@field public decommision fun(self: self) --- Returns true if no stations exist in this yard
---@field public tick fun(self: self, controller: rsad_controller)

--- TODO: Make custom schedules possible

--- Removes the station if it exists from all registers
---@param yard TrainYard
---@param station RSADStation
local function remove_station(yard, station)
    yard[rsad_station_type.shunting_depot][station.unit_number] = nil
    for stage, sta in pairs(yard[rsad_station_type.turnabout]) do
        if sta and sta.unit_number == station.unit_number then
            yard[rsad_station_type.turnabout][stage] = nil
        end
    end
    yard[rsad_station_type.import_staging][station.unit_number] = nil
    for i,v in pairs(yard[rsad_station_type.import]) do
        v[station] = nil
        if next(v) == nil then
            yard[rsad_station_type.import][i] = nil
        end
    end
    yard[rsad_station_type.request][station.unit_number] = nil
    yard[rsad_station_type.empty_staging][station.unit_number] = nil
    yard[rsad_station_type.empty_pickup][station.unit_number] = nil
end

---@param yard TrainYard
---@return boolean
local function is_empty(yard)
    return next(yard[rsad_station_type.shunting_depot]) == nil and
           next(yard[rsad_station_type.turnabout]) == nil and
           next(yard[rsad_station_type.import_staging]) == nil and
           next(yard[rsad_station_type.import]) == nil and
           next(yard[rsad_station_type.request]) == nil and
           next(yard[rsad_station_type.empty_staging]) == nil and
           next(yard[rsad_station_type.empty_pickup]) == nil
end

--- Adds the station to the relevant array or modifies an existing station to a new designation
---@param yard TrainYard
---@param station RSADStation
---@return boolean success
local function add_or_update_station(yard, station)
    local success, data = get_station_data(station)
    yard:remove_station(station)

    if not success or not data or not data.type then return false end

    if data.type == rsad_station_type.turnabout then
        yard[data.type][data.subtype] = station
    elseif data.type == rsad_station_type.import and data.item and data.item.name then
        yard[data.type][data.item.name] = yard[data.type][data.item.name] or {}
        yard[data.type][data.item.name][station.unit_number] = station
    elseif data.type == rsad_station_type.request and data.item and data.item.name then
        yard[data.type][station.unit_number] = data.item.name
    else
        yard[data.type][station.unit_number] = station
    end

    update_station_data(station, {network = yard.network})

    return true
end

local function decommision_yard()

end

---Checks for empty wagons, submits requests, and manages idle shunters
---@param yard TrainYard
---@param controller rsad_controller
---@return boolean ---True if tick was processed and blocks other updates. False if update should continue
local function tick(yard, controller)
    -- Update checks below are sorted by importance
    -- Check for empty wagons, and missing requests
    if yard[rsad_station_type.import] and next(yard[rsad_station_type.import]) ~= nil then -- Make sure there's an import station to request from
        for unit, item in pairs(yard[rsad_station_type.request]) do
            local station = controller.stations[unit]
            if not station then goto continue end
            local data_success, data = get_station_data(station)
            if station.parked_train then
                local contents = game.train_manager.get_train_by_id(station.parked_train).get_contents()
                if not contents or next(contents) == nil then
                    local schedule_success, error = controller.scheduler:queue_shunt_wagon_to_empty(controller, station)
                    if not schedule_success and error then
                        game.print("Scheduling error code " .. error .. " at station " .. station.unit_number .. ". Please report this with the log file to the mod developer.")
                        log("Scheduling error code " .. error .. " at station " .. station.unit_number .. ". Please report this with the log file to the mod developer.")
                        controller:decommision_station_from_yard(station)
                        goto continue
                    end
                end
            elseif not station.parked_train
                   and (data_success and data and station.assignments < data.train_limit) then -- Check for already requested

                local schedule_success, error = controller.scheduler:queue_station_request(controller, station)
                if not schedule_success and error then
                    game.print("Scheduling error code " .. error .. ". Please report this with the log file to the mod developer.")
                    log("Scheduling error code " .. error .. ". Please report this with the log file to the mod developer.")
                    goto continue
                end
            end
            ::continue::
        end
        return true
    end

    return false
end

---Creates a new TrainYard object
---@param network SignalID
---@return TrainYard
function create_train_yard(network)
    --storage.shunter_trains[network] = {}
    local yard = {
        network = network,
        [rsad_station_type.shunting_depot] = {},
        [rsad_station_type.turnabout] = {}, -- maps the shunting_stage to the station
        [rsad_station_type.import_staging] = {}, -- list of staging for imports. If included the imports will be sorted from here into the import stations. It's best to also include a bypass for trains with a single import
        [rsad_station_type.import] = {}, -- list of all import stations and their item. Can only be assigned to a single item
        [rsad_station_type.request] = {}, -- list of all request stations and their requested item. Can only be assigned to a single item
        [rsad_station_type.empty_staging] = {}, -- staging for empty wagons
        [rsad_station_type.empty_pickup] = {}, -- staging for empty wagons
        --shunter_trains = storage.shunter_trains[network],

        -- Functions
        add_or_update_station = add_or_update_station,
        remove_station = remove_station,
        is_empty = is_empty,
        decommision = decommision_yard,
        tick = tick
    }
    --[[@type TrainYard]]
    return yard
end