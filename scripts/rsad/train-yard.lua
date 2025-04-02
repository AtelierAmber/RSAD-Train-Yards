require("scripts.defines")
require("scripts.rsad.station")

local next = next -- Assign local table next for indexing speed

---@class RSAD.TrainYard.ShuntingData
---@field public current_stage rsad_shunting_stage
---@field public pickup_info uint
---@field public scheduled_stations table<uint, RSAD.Station> -- Stations this shunter is visiting. Maps schedule.current to station

---@see create_train_yard
---@class RSAD.TrainYard
---@field public network SignalID
---@field public rsad_station_type.shunting_depot {[uint]: RSAD.Station} 
---@field public rsad_station_type.turnabout {[rsad_shunting_stage]: RSAD.Station}
---@field public rsad_station_type.import_staging {[uint]: RSAD.Station}
---@field public rsad_station_type.import {[string]: {[uint]: RSAD.Station}} -- Maps item to RSADStations
---@field public rsad_station_type.request {[uint]: string} --- Maps RSADStation to their item request
---@field public rsad_station_type.empty_staging {[uint]: RSAD.Station}
---@field public rsad_station_type.empty_pickup {[uint]: RSAD.Station}
---@field public shunter_trains {[uint]: RSAD.TrainYard.ShuntingData}
---Functions
---@field public add_or_update_station fun(self: self, station: RSAD.Station): boolean --- Adds the station to the relevant array. Returns success
---@field public remove_station fun(self: self, unit_number: number) --- Removes the station from yard
---@field public is_empty fun(self: self): boolean --- Returns true if no stations exist in this yard
---@field public decommision fun(self: self) --- Returns true if no stations exist in this yard
---@field public add_new_shunter fun(self:self, train_id: integer)
---@field public remove_shunter fun(self:self, train_id: integer)
---@field public redefine_shunter fun(self:self, old_id: integer, new_id: integer)
---@field public update fun(self: self, controller: RSAD.Controller)

--- TODO: Make custom schedules possible

--- Removes the station if it exists from all registers
---@param self RSAD.TrainYard
---@param unit_number number
local function remove_station(self, unit_number)
    self[rsad_station_type.shunting_depot][unit_number] = nil
    for stage, sta in pairs(self[rsad_station_type.turnabout]) do
        if sta and sta.unit_number == unit_number then
            self[rsad_station_type.turnabout][stage] = nil
        end
    end
    self[rsad_station_type.import_staging][unit_number] = nil
    for i,v in pairs(self[rsad_station_type.import]) do
        v[unit_number] = nil
        if next(v) == nil then
            self[rsad_station_type.import][i] = nil
        end
    end
    self[rsad_station_type.request][unit_number] = nil
    self[rsad_station_type.empty_staging][unit_number] = nil
    self[rsad_station_type.empty_pickup][unit_number] = nil
end

---@param self RSAD.TrainYard
---@return boolean
local function is_empty(self)
    return next(self[rsad_station_type.shunting_depot]) == nil and
           next(self[rsad_station_type.turnabout]) == nil and
           next(self[rsad_station_type.import_staging]) == nil and
           next(self[rsad_station_type.import]) == nil and
           next(self[rsad_station_type.request]) == nil and
           next(self[rsad_station_type.empty_staging]) == nil and
           next(self[rsad_station_type.empty_pickup]) == nil
end

---@param self RSAD.TrainYard
---@param train_id integer
local function add_new_shunter(self, train_id)
    self.shunter_trains[train_id] = {current_stage = rsad_shunting_stage.available, pickup_info = 0, scheduled_stations = {}}
end

---@param self RSAD.TrainYard
---@param train_id integer
local function remove_shunter(self, train_id)
    self.shunter_trains[train_id] = nil
end

---@param self RSAD.TrainYard
---@param old_id integer
---@param new_id integer
local function redefine_shunter(self, old_id, new_id)
    if old_id == new_id then return end
    local old = self.shunter_trains[old_id]
    if not old then return end
    self.shunter_trains[old_id] = nil
    self.shunter_trains[new_id] = old
end

--- Adds the station to the relevant array or modifies an existing station to a new designation
---@param self RSAD.TrainYard
---@param station RSAD.Station
---@return boolean success
local function add_or_update_station(self, station)
    local success, station_entity, data = get_station_data(station)
    self:remove_station(station.unit_number)

    if not success or not data.type then return false end

    if data.type == rsad_station_type.turnabout then
        self[data.type][data.subinfo] = station
    elseif data.type == rsad_station_type.import then
        if data.request then
            local hash = signal_hash(data.request)
            if hash then
                self[data.type][hash] = self[data.type][hash] or {}
                self[data.type][hash][station.unit_number] = station
            end
        end
    elseif data.type == rsad_station_type.request then
        if data.request then
            local hash = signal_hash(data.request)
            if hash then
                self[data.type][station.unit_number] = hash
            end
        end
    else
        self[data.type][station.unit_number] = station
    end

    if data.type == rsad_station_type.shunting_depot then
        if station_entity then
            local train = station_entity.get_stopped_train()
            if train then add_new_shunter(self, train.id) end
        end
    end

    update_station_data(station, { network = self.network })

    return true
end

local function decommision_yard()

end

---@param self RSAD.TrainYard
---@param controller RSAD.Controller
---@param station RSAD.Station
---@param station_entity LuaEntity
---@param request string
---@param data RSAD.Station.Data
---@return RSAD.Station.Status
local function get_requester_status(self, controller, station, station_entity, request, data)
    if not data.train_limit or ((station.incoming + table_size(station_entity.get_train_stop_trains())) >= data.train_limit)  -- Check for already requested
       or signal_hash(data.request) ~= request
       or not self[rsad_station_type.import][request] or next(self[rsad_station_type.import][request]) == nil then -- Make sure we have an import station for this request
        return rsad_station_status.idle end 

    if station.parked_train then
        local parked_train = game.train_manager.get_train_by_id(station.parked_train)
        if not parked_train then controller:free_parked_station(station) return rsad_station_status.idle end --Delay for one update to reduce possibility of race condition
        local contents = parked_train.get_contents()
        if not contents or next(contents) == nil then return rsad_station_status.has_empty end
        return rsad_station_status.inactive
    else
        return rsad_station_status.needs_request
    end
end

---Checks for empty wagons, submits requests, and manages idle shunters
---@param self RSAD.TrainYard
---@param controller RSAD.Controller
---@return boolean ---True if tick was processed and blocks other updates. False if update should continue
local function update(self, controller)
    -- Update checks below are sorted by importance
    -- Check for empty wagons, and missing requests
    local decom = {}
    local updated = false
    if self[rsad_station_type.import] and next(self[rsad_station_type.import]) ~= nil then -- Make sure there's an import station to request from
        updated = true
        for unit, request in pairs(self[rsad_station_type.request]) do
            local station = controller.stations[unit]
            if not station then decom[unit] = unit goto continue end
            local data_success, station_entity, data = get_station_data(station)
            if not data_success then goto continue end

            local status = get_requester_status(self, controller, station, station_entity, request, data)
            local schedule_success, error
            if status == rsad_station_status.needs_request then
                schedule_success, error = controller.scheduler:queue_station_request(station)
            elseif status == rsad_station_status.has_empty then
                schedule_success, error = controller.scheduler:queue_shunt_wagon_to_empty(station)
            end

            if not schedule_success and error then
                game.print("Scheduling error code " .. error .. " at station " .. station.unit_number .. ". Please report this with the log file to the mod developer.")
                log({"", "Scheduling error code " .. error .. " at station " .. station.unit_number .. ". Please report this with the log file to the mod developer."})
                controller:decommision_station_from_yard(station)
                goto continue
            end

            ::continue::
        end
    end

    for _, unit in pairs(decom) do
        self:remove_station(unit)
    end
    return updated
end

local TrainYardMeta = {
    __index = {
        add_or_update_station = add_or_update_station,
        remove_station = remove_station,
        is_empty = is_empty,
        decommision = nil, --Unimplemented
        add_new_shunter = add_new_shunter,
        remove_shunter = remove_shunter,
        update = update,
        redefine_shunter = redefine_shunter,
    }
}
script.register_metatable("TrainYardMeta", TrainYardMeta)

---Creates a new TrainYard object
---@param network SignalID
---@return RSAD.TrainYard
function create_train_yard(network)
    local hash = signal_hash(network)
    assert(hash, "Could not hash network " .. serpent.line(network))
    --[[@type RSAD.TrainYard]]
---@diagnostic disable-next-line: missing-fields
    local yard = setmetatable({
        network = network,
        [rsad_station_type.shunting_depot] = {},
        [rsad_station_type.turnabout] = {}, -- maps the shunting_stage to the station
        [rsad_station_type.import_staging] = {}, -- list of staging for imports. If included the imports will be sorted from here into the import stations. It's best to also include a bypass for trains with a single import
        [rsad_station_type.import] = {}, -- list of all import stations and their item. Can only be assigned to a single item
        [rsad_station_type.request] = {}, -- list of all request stations and their requested item. Can only be assigned to a single item
        [rsad_station_type.empty_staging] = {}, -- staging for empty wagons
        [rsad_station_type.empty_pickup] = {}, -- staging for empty wagons
        shunter_trains = {},
    }, TrainYardMeta)
    
    storage.train_yards[hash] = yard
    return yard
end