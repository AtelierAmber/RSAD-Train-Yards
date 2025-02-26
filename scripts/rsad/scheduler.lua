require("scripts.rsad.station")
require("scripts.rsad.rsad-controller")

-- TODO: Expand to inter-yard deliveries

---@param station RSADStation
---@return boolean, uint?, uint? --- Whether or not the request was successful, unit_number for the train assigned to delivery (nil if failed), error number (nil if successful) 
function handle_station_request(station)
    if not station then return false, nil, 3 end
    local success, data = get_station_data(station)
    if not success or not data then return false, nil, 4 end
    
    local yard = get_or_create_train_yard(data.network) ---@type TrainYard?
    if not yard then return false, nil, 2 end


    return true, assigned_train
end