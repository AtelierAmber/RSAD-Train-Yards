require("scripts.rsad.station")
require("scripts.rsad.rsad-controller")

-- TODO: Expand to inter-yard deliveries

---@param station RSADStation
---@return boolean, uint?, uint? --- Whether or not the request was successful, unit_number for the train assigned to delivery (nil if failed), error number (nil if successful) 
function handle_station_request(station)
    if not station then return false, nil, 3 end
    
    local yard = get_or_create_train_yard(station.network) ---@type TrainYard
    local request = station.item
    local assigned_train ---@type uint

    if not yard or #yard.shunting_depots == 0 or not yard.import_stations[request] then return false, nil, 2 end

    return true, assigned_train
end