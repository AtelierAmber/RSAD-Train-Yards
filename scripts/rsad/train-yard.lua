TrainYard = {}

TrainYard.__index = TrainYard

function TrainYard:new(network)
    local yard = {}
    setmetatable(yard, TrainYard)
    yard.network = network
    yard.shunting_depots = {}
    yard.turnabouts = {} -- maps the shunting_stage to the station
    yard.staging_import_stations = {} -- list of staging for imports. If included the imports will be sorted from here into the import stations. It's best to also include a bypass for trains with a single import
    yard.import_stations = {} -- list of all import stations and their item. Can only be assigned to a single item
    yard.request_stations = {} -- list of all request stations and their requested items in order from front (closest to station) to rear (furthest from station)
    yard.staging_empty = {} -- staging for empty wagons
end

---@enum shunting_stage
shunting_stage = {
    sort_imports = 0 --[[@as shunting_stage.sort_imports ]], -- taking wagons from staging_import_stations into their respective import_stations
    delivery = 2 --[[@as shunting_stage.delivery ]], -- delivering from import_stations to request_stations
    clear_empty = 4 --[[@as shunting_stage.clear_empty ]] -- clearing empty wagons and shunt them to the staged train if possible
}

