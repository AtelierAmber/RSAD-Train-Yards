require("scripts.rsad.station")

---@enum shunting_stage
shunting_stage = {
    sort_imports = 0 --[[@as shunting_stage.sort_imports ]], -- taking wagons from staging_import_stations into their respective import_stations
    delivery = 2 --[[@as shunting_stage.delivery ]], -- delivering from import_stations to request_stations
    clear_empty = 4 --[[@as shunting_stage.clear_empty ]] -- clearing empty wagons and shunt them to the staged train if possible
}

---@class TrainYard
---@field public network string
---@field public shunting_depots {[uint]: RSADStation}
---@field public turnabouts {[shunting_stage]: RSADStation}
---@field public import_staging_stations {[uint]: RSADStation}
---@field public import_stations {[string]: RSADStation}
---@field public request_stations {[uint]: string} --- Maps unit_number of station to their item request
---@field public staging_empty {[uint]: RSADStation}

__TrainYard = {}

__TrainYard.__index = __TrainYard

--- TODO: Make custom schedules possible

---Creates a new TrainYard object
---@param network string
---@return TrainYard?
function __TrainYard:new(network)
    if not data.raw["virtual-signal"][network] then
        return nil
    end
    
    local yard = {}
    setmetatable(yard, __TrainYard)
    yard.network = network
    yard.shunting_depots = {}
    yard.turnabouts = {} -- maps the shunting_stage to the station
    yard.import_staging_stations = {} -- list of staging for imports. If included the imports will be sorted from here into the import stations. It's best to also include a bypass for trains with a single import
    yard.import_stations = {} -- list of all import stations and their item. Can only be assigned to a single item
    yard.request_stations = {} -- list of all request stations and their requested item. Can only be assigned to a single item
    yard.staging_empty = {} -- staging for empty wagons
    return yard
end
