require("scripts.rsad.station")

---@type flib_queue
queue = require("__flib__.queue")
-- TODO: Expand to inter-yard deliveries

---@class scheduler
scheduler = {

}
pending_changes = queue.new()

---@param station RSADStation
---@param controller rsad_controller
---@return boolean, uint?, uint? --- Whether or not the request was successful, unit_number for the train assigned to delivery (nil if failed), error number (nil if successful) 
function handle_station_request(controller, station)
    if not station then return false, nil, 3 end
    local success, data = get_station_data(station)
    if not success or not data then return false, nil, 4 end
    
    local yard = controller:get_or_create_train_yard(data.network) ---@type TrainYard?
    if not yard then return false, nil, 2 end


    return true, assigned_train
end

function scheduler.tick(self)
    return false
end

return scheduler