---@enum station_type
station_type = {
    turnabout = 0 --[[@as station_type.turnabout ]], -- 
    shunting_depot = 2 --[[@as station_type.shunting_depot ]], -- 
    import_staging = 4 --[[@as station_type.import_staging ]], -- 
    import = 8 --[[@as station_type.import ]], -- 
    request = 16 --[[@as station_type.request ]], -- 
    empty_staging = 32 --[[@as station_type.empty_staging ]], -- 
    empty_pickup = 64 --[[@as station_type.empty_pickup ]], -- 
}

---@class RSADStation
---@field public unit_number uint
---@field public type station_type