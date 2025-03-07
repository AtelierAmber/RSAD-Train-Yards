require("scripts.rsad.train-yard")
require("scripts.rsad.util")

---@param train LuaTrain
---@param station_entity LuaEntity
---@return LuaEntity, defines.rail_direction
local function get_front_stock(train, station_entity)
    local front_dist = position_distance(train.front_stock.position, station_entity.position)
    local back_dist = position_distance(train.back_stock.position, station_entity.position)
    if front_dist < back_dist then return train.front_stock, defines.rail_direction.front end
    return train.back_stock, defines.rail_direction.back
end

---@param self rsad_controller
---@param train LuaTrain
---@param station RSADStation
---@param count uint?
---@return boolean success
function rsad_controller.attempt_couple_at_station(self, train, station, count)
    local success, entity, station_data = get_station_data(station)
    if not success or not entity or not station_data then return false end
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
        self.scheduler:move_train_by_wagon_count(train, connected_stock, count * ((connected_stock.is_headed_to_trains_front and -1) or 1))
    end

    local new_train_id = train.id

    local yard = self:get_train_yard_or_nil(station_data.network)
    if not yard then return true end

    yard:redefine_shunter(old_train_id, new_train_id)

    return true
end

---@param self rsad_controller
---@param train LuaTrain
---@param at LuaEntity
---@param direction defines.rail_direction
function rsad_controller.decouple_at(self, train, at, direction)
    local old_train_id = train.id
    local schedule = train.schedule
    local s = at.get_connected_rolling_stock(direction)
    local b = at.disconnect_rolling_stock(direction)
    local new_train_id = at.train.id
    --TODO FIX SHUNTER ASSIGNMENT
    at.train.schedule = schedule
    at.train.manual_mode = false
end