require("scripts.rsad.train-yard")
require("scripts.rsad.util")

---@param self rsad_controller
---@param train LuaTrain
---@param station RSADStation
---@param count uint?
---@return boolean success
function rsad_controller.attempt_couple_at_station(self, train, station, count)
    local success, entity, station_data = get_station_data(station)
    if not success then return false end
    local old_train_id, old_train_length = train.id, table_size(train.carriages)
    local schedule = train.schedule

    local front_stock, front_direction = get_front_stock(train, entity)
    local connect_dir = front_stock.get_connected_rolling_stock(defines.rail_direction.front) and defines.rail_direction.back or defines.rail_direction.front
    if not front_stock.connect_rolling_stock(connect_dir) then return false end

    train = front_stock.train
    if not train then return false end

    train.schedule = schedule
    if schedule then train.go_to_station(schedule.current+1) end

    if count and (old_train_length + count) < table_size(train.carriages) then
        local connected_stock = front_stock.get_connected_rolling_stock(connect_dir)
        if not connected_stock then return false end
        self.scheduler:move_train_by_wagon_count(train, connected_stock, count * ((connected_stock.is_headed_to_trains_front and -1) or 1), signal_hash(station_data.network) or "", station)
    end

    local new_train_id = train.id

    local yard = self:get_train_yard_or_nil(station_data.network)
    if not yard then return true end

    yard:redefine_shunter(old_train_id, new_train_id)

    return true
end

---@param self rsad_controller
---@param train LuaTrain
---@param station RSADStation
---@return boolean success, LuaTrain? new_train
function rsad_controller.decouple_all_cargo(self, train, station, is_shunter)
    local start, direction = get_back_cargo(train)

    local wagon = start
    local next_wagon = start --[[@as LuaEntity?]]
    if wagon.type == "locomotive" then return false end
    while true do
        next_wagon = wagon.get_connected_rolling_stock(direction)
        assert(next_wagon ~= nil, "Failed to decouple. No Locomotive found to decouple from.")
        --[[@cast next_wagon LuaEntity]]
        if next_wagon.type == "locomotive" then break end
        wagon = next_wagon
    end
    
    local old_train_id = train.id
    local schedule = train.schedule --[[@as TrainSchedule]]
    if not wagon.disconnect_rolling_stock(direction) then return false end
    train = next_wagon.train --[[@as LuaTrain]]
    local new_train_id = next_wagon.train.id or old_train_id
    if schedule.current < #schedule.records then
        schedule.current = schedule.current + 1
    end
    train.schedule = schedule
    train.manual_mode = false

    if not is_shunter then return false end

    local success, entity, station_data = get_station_data(station)
    if not success then return false end

    local yard = self.train_yards[signal_hash(station_data.network)] --[[@type TrainYard]]
    if not yard then return true, train end

    yard:redefine_shunter(old_train_id, new_train_id)
    station.parked_train = wagon.train.id

    return true, train
end

---@param self rsad_controller
---@param train LuaTrain
---@param at LuaEntity
---@param direction defines.rail_direction
---@param network string
---@param assign_to RSADStation
function rsad_controller.decouple_at(self, train, at, direction, network, assign_to)
    local old_train_id = train.id
    local schedule = train.schedule
    local other = at.get_connected_rolling_stock(direction == defines.rail_direction.front and defines.rail_direction.back or defines.rail_direction.front)
    if at.disconnect_rolling_stock(direction) then
        local new_train_id = at.train.id
        at.train.schedule = schedule
        at.train.manual_mode = false
    
        local yard = self.train_yards[network]
        if not yard then return end
    
        yard:redefine_shunter(old_train_id, new_train_id)
        if other then
            assign_to.parked_train = other.train.id
        end
    end
end