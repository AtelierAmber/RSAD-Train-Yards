require("scripts.rsad.train-yard")

function init_controller()
    storage.rsad_data = storage.rsad_data or {}
    storage.rsad_stations = storage.rsad_data.stations or {}
    storage.rsad_train_yards = storage.rsad_train_yards or {}
end

function add_rsad_station(rsad_station_entity)
    
end

---Creates or returns an existing train yard with specified signal
---@param virtual_signal string
---@return TrainYard
function create_or_get_train_yard(virtual_signal)
    storage.rsad_train_yards[virtual_signal] = storage.rsad_train_yards[virtual_signal] or __TrainYard:new(virtual_signal)
    return storage.rsad_train_yards[virtual_signal]
end