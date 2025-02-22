---@enum rsad_station_type
rsad_station_type = {
    turnabout = "*" --[[@as rsad_station_type.turnabout ]], -- 
    shunting_depot = "/" --[[@as rsad_station_type.shunting_depot ]], -- 
    import_staging = "+" --[[@as rsad_station_type.import_staging ]], -- 
    import = "<<" --[[@as rsad_station_type.import ]], -- 
    request = ">>" --[[@as rsad_station_type.request ]], -- 
    empty_staging = "-" --[[@as rsad_station_type.empty_staging ]], -- 
    empty_pickup = "^" --[[@as rsad_station_type.empty_pickup ]], -- 
}
rsad_station_index = {}
rsad_station_index[rsad_station_type.turnabout] = 1
rsad_station_index[rsad_station_type.shunting_depot] = 2
rsad_station_index[rsad_station_type.import_staging] = 3
rsad_station_index[rsad_station_type.import] = 4
rsad_station_index[rsad_station_type.request] = 5
rsad_station_index[rsad_station_type.empty_staging] = 6
rsad_station_index[rsad_station_type.empty_pickup] = 7
rsad_index_station = {}
rsad_index_station[1] = rsad_station_type.turnabout
rsad_index_station[2] = rsad_station_type.shunting_depot
rsad_index_station[3] = rsad_station_type.import_staging
rsad_index_station[4] = rsad_station_type.import
rsad_index_station[5] = rsad_station_type.request
rsad_index_station[6] = rsad_station_type.empty_staging
rsad_index_station[7] = rsad_station_type.empty_pickup

---@enum shunting_stage
shunting_stage = {
    sort_imports = 0 --[[@as shunting_stage.sort_imports ]], -- taking wagons from import_staging_stations into their respective import_stations
    delivery = 1 --[[@as shunting_stage.delivery ]], -- delivering from import_stations to request_stations
    clear_empty = 2 --[[@as shunting_stage.clear_empty ]] -- clearing empty wagons and shunt them to the staged train if possible
} 
