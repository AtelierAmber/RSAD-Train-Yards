require("scripts.rsad.train-yard")
require("scripts.rsad.station")

rsad_controller = {
    stations = {}, --[[@type table<uint, RSADStation>]]
    train_yards = {} --[[@type table<string, TrainYard>]]
}

function init_controller()
    ---@type table<uint, RSADStation> unit_number to station data
    rsad_controller.stations = storage.rsad_stations or {}
    ---@type table<string, TrainYard> network to yard data
    rsad_controller.train_yards = storage.rsad_train_yards or {}
end

---@param signal SignalID
---@return TrainYard?
function get_train_yard_or_nil(signal)
    local hash = signal_hash(signal)
    return hash and rsad_controller.train_yards[hash]
end

---comment
---@param signal SignalID?
---@return string? hash
function signal_hash(signal)
    local signal_type = signal and signal.type or "item-name" --[[@as string?]]
    if signal_type == "virtual" then signal_type = "virtual-signal" end
    return (signal_type and (signal and signal.name) and (signal_type .. "-name".. "." .. signal.name))
end

---Get or creates a train yard with specified signal
---@param signal SignalID
---@return TrainYard? yard
function get_or_create_train_yard(signal)
    local hash = signal_hash(signal)
    if not hash then return nil end
    rsad_controller.train_yards[hash] = rsad_controller.train_yards[hash] or create_train_yard(signal)
    return rsad_controller.train_yards[hash]
end

---comment
---@param hash string
---@return TrainYard
function get_or_create_train_yard_hash(hash)
    rsad_controller.train_yards[hash] = rsad_controller.train_yards[hash] or create_train_yard(hash)
    return rsad_controller.train_yards[hash]
end

---Returns false if needed to create, true if it was found
---@param entity LuaEntity
---@param network SignalID?
---@return boolean, RSADStation? 
function get_or_create_station(entity, network)
    local unit_number = entity.unit_number
    
    local station = rsad_controller.stations[unit_number] --[[@as RSADStation?]]
    if not station and network then
        station = construct_station(entity, network)
        return false, station
    end
    return true, station
end

--- Creates station and assignes it to a train yard
---@param entity LuaEntity
---@param network SignalID
---@return RSADStation?
function construct_station(entity, network)
    local yard = get_or_create_train_yard(network)
    if not yard then
        return nil
    end

    local station = create_rsad_station(entity)
    if not station then
        return nil
    end

    rsad_controller.stations[entity.unit_number] = station
    station:update({network = network})
    yard:add_or_update_station(station)
    return station
end

---comment
---@param station RSADStation
function decommision_station(station)
    if not station then return end
    local success, data = station:data()
    if not success or not data then
        rsad_controller.stations[station.unit_number] = nil
        return
    end

    local yard = data.network and rsad_controller.train_yards[signal_hash(data.network)]
    if yard then 
        yard:remove_station(station)
    end

    station:decommision()
    rsad_controller.stations[station.unit_number] = nil
end

---comment
---@param station RSADStation
---@param new_network SignalID
---@return boolean
function migrate_station(station, new_network)
    local new_yard = get_or_create_train_yard(new_network)
    if not new_yard then return false end
    
    decommision_station(station)
    return new_yard:add_or_update_station(station)
end