require("scripts.rsad.train-yard")
require("scripts.rsad.station")
require("scripts.util.events")

rsad_controller = {
    stations = {}, --[[@type table<uint, RSADStation>]]
    train_yards = {} --[[@type table<string, TrainYard>]]
}

local function init()
    --storage.stations = {}
    --storage.shunter_trains = {} --[[@type table<string, table<uint, ShuntingData>>}]]
end

local function load()
    if storage.shunter_trains then
        for network, trains in pairs(storage.shunter_trains) do
            
        end
    end
end

local function tick()
    for network, yard in pairs(rsad_controller.train_yards) do
        
    end
end

---@param entity LuaEntity
---@return boolean
local function on_station_destroyed(entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return true end

    local station = rsad_controller.stations[entity.unit_number]
    if not station then return true end

    decommision_station(station)
    game.print(serpent.block(rsad_controller.stations))
    return true
end

---@param entity LuaEntity
---@return boolean
local function on_station_built(entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return true end

    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local network = control.stopped_train_signal --[[@as SignalID?]]
    if network then
        local found, station = get_or_create_station(entity, network)
        if found and station then
            migrate_station(station, network)
        end
    end

    return true
end

---@param entity LuaEntity
local function on_paste_settings(entity)
    if entity.name == "entity-ghost" or entity.name ~= names.entities.rsad_station then return end
    
    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local network = control.stopped_train_signal --[[@as SignalID?]]
    if network then
        local found, station = get_or_create_station(entity, network)
        if found and station then
            migrate_station(station, network)
        end
    end
end

function rsad_controller.register_events()
   register_init(init)
   register_load(load)
   register_break("name", names.entities.rsad_station, on_station_destroyed)
   register_build("name", names.entities.rsad_station, on_station_built)
   register_paste(on_paste_settings)
end

---@param entity LuaEntity
---@param control LuaTrainStopControlBehavior
---@param index uint
function update_station_name(entity, control, index)
    local network_name = "Unassigned"
    if control.stopped_train_signal and control.stopped_train_signal.name then
        network_name = (control.stopped_train_signal.type or "item")
        if network_name == "virtual" then
            network_name = network_name .. "-signal"
        end
        network_name = network_name .. "=" .. control.stopped_train_signal.name
    end
    local item_name = ""
    if control.priority_signal and (index == rsad_station_type.import or index == rsad_station_type.request) then 
        item_name = "[" .. (("item=" .. control.priority_signal.name) or "No Item") .. "]"
    end
    entity.backer_name = "RSAD Controlled | [" .. network_name .. "] " .. rsad_station_name[index] .. item_name
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
    update_station_data(station, {network = network})
    yard:add_or_update_station(station)
    return station
end

---comment
---@param station RSADStation
function decommision_station_from_yard(station)
    if not station then return end
    local success, data = get_station_data(station)
    if not success or not data then
        rsad_controller.stations[station.unit_number] = nil
        return
    end

    local hash = signal_hash(data.network)
    if hash then
        local yard = data.network and rsad_controller.train_yards[hash] --[[@as TrainYard?]]
        if yard then 
            yard:remove_station(station)
            if yard:is_empty() then
                rsad_controller.train_yards[hash] = nil
            end
        end
    end

    decommision_station(station)
    rsad_controller.stations[station.unit_number] = nil
end

---comment
---@param station RSADStation
---@param new_network SignalID
---@return boolean
function migrate_station(station, new_network)
    local new_yard = get_or_create_train_yard(new_network)
    if not new_yard then return false end
    
    decommision_station_from_yard(station)
    return new_yard:add_or_update_station(station)
end