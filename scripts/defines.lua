---@enum rsad_station_type
rsad_station_type = {
    turnabout = 0 --[[@as rsad_station_type.turnabout ]], -- 
    shunting_depot = 1 --[[@as rsad_station_type.shunting_depot ]], -- 
    import_staging = 2 --[[@as rsad_station_type.import_staging ]], -- 
    import = 3 --[[@as rsad_station_type.import ]], -- 
    request = 4 --[[@as rsad_station_type.request ]], -- 
    empty_staging = 5 --[[@as rsad_station_type.empty_staging ]], -- 
    empty_pickup = 6 --[[@as rsad_station_type.empty_pickup ]], -- 
}

rsad_station_name = {}
rsad_station_name[rsad_station_type.turnabout] = "Turnabout"
rsad_station_name[rsad_station_type.shunting_depot] = "Shunting Depot"
rsad_station_name[rsad_station_type.import_staging] = "Multi-Item Import Staging"
rsad_station_name[rsad_station_type.import] = "Single-Item Import Queue"
rsad_station_name[rsad_station_type.request] = "Requester"
rsad_station_name[rsad_station_type.empty_staging] = "Empty Wagon Staging"
rsad_station_name[rsad_station_type.empty_pickup] = "Empty Wagon Pickup"

---@enum rsad_shunting_stage
rsad_shunting_stage = {
    available = 0, --[[@as rsad_shunting_stage.available ]]
    sort_imports = 1 --[[@as rsad_shunting_stage.sort_imports ]], -- taking wagons from import_staging_stations into their respective import_stations
    delivery = 2 --[[@as rsad_shunting_stage.delivery ]], -- delivering from import_stations to request_stations
    clear_empty = 3 --[[@as rsad_shunting_stage.clear_empty ]], -- clearing empty wagons and shunt them to the staged train if possible
    return_to_depot = 4 --[[@as rsad_shunting_stage.delivery ]], -- returning from other stage
} 

rsad_stage_name = {}
rsad_stage_name[rsad_shunting_stage.available] = "Available"
rsad_stage_name[rsad_shunting_stage.sort_imports] = "Import Sorting"
rsad_stage_name[rsad_shunting_stage.delivery] = "Item Delivery"
rsad_stage_name[rsad_shunting_stage.clear_empty] = "Empty Wagon Clear"
rsad_stage_name[rsad_shunting_stage.return_to_depot] = "Depot Return"

STATION_TYPE_ID = 0
STATION_TYPE_ID_WIDTH = 4
SHUNTING_DIRECTION = 4
SHUNTING_DIRECTION_WIDTH = 1
STATION_SUBINFO = 5
STATION_SUBINFO_WIDTH = 8