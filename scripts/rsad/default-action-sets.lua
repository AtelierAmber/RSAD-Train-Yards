require("scripts.rsad.station-actions")
require("scripts.defines")

---@param station_data RSAD.Station.Data
---@return table<rsad_shunting_stage, RSAD.Actions.Set>
function RSAD_Actions.create_action_set(station_data)
    local sets = {}
    if station_data.type == rsad_station_type.turnabout then
        RSAD_Actions.open_set()
        RSAD_Actions.leave_station()
        sets[rsad_shunting_stage.unspecified] = RSAD_Actions.close_set()
    elseif station_data.type == rsad_station_type.shunting_depot then
        RSAD_Actions.open_set()
        RSAD_Actions.define_as_shunter()
        sets[rsad_shunting_stage.unspecified] = RSAD_Actions.close_set()
    elseif station_data.type == rsad_station_type.request then
        RSAD_Actions.open_set()
        RSAD_Actions.decouple(0, false, {runtime = true, variable = RuntimeParamType.starting.train.arrival_direction})
        RSAD_Actions.leave_station()
        sets[rsad_shunting_stage.delivery] = RSAD_Actions.close_set()

        RSAD_Actions.open_set()
        RSAD_Actions.couple({runtime = true, variable = RuntimeParamType.starting.train.arrival_direction})
        RSAD_Actions.leave_station()
        sets[rsad_shunting_stage.clear_empty] = RSAD_Actions.close_set()
    elseif station_data.type == rsad_station_type.import_staging then
    elseif station_data.type == rsad_station_type.import then
        RSAD_Actions.open_set()
        RSAD_Actions.couple({runtime = true, variable = RuntimeParamType.starting.train.arrival_direction})
        RSAD_Actions.align_to_segment({
            offset_from = {runtime = true, variable = RuntimeParamType.starting.train.reversed_direction}, 
            move_direction = {runtime = true, variable = RuntimeParamType.starting.train.reversed_direction},
            align_side = {runtime = true, variable = RuntimeParamType.starting.train.arrival_direction},
            ignore_locomotives = false,
            offset_num = {runtime = true, variable = RuntimeParamType.starting.train.pickup_info}
        })
        RSAD_Actions.decouple({runtime = true, variable = RuntimeParamType.starting.train.pickup_info}, false, {runtime = true, variable = RuntimeParamType.starting.train.arrival_direction})
        RSAD_Actions.leave_station()
        sets[rsad_shunting_stage.delivery] = RSAD_Actions.close_set()
        RSAD_Actions.open_set()
        RSAD_Actions.decouple(0, false, {runtime = true, variable = RuntimeParamType.starting.train.arrival_direction})
        RSAD_Actions.leave_station()
        sets[rsad_shunting_stage.unspecified] = RSAD_Actions.close_set()
    elseif station_data.type == rsad_station_type.empty_staging then
        RSAD_Actions.open_set()
        RSAD_Actions.couple({runtime = true, variable = RuntimeParamType.starting.train.arrival_direction})
        RSAD_Actions.align_to_segment({
            offset_from = {runtime = true, variable = RuntimeParamType.starting.train.reversed_direction}, 
            move_direction = {runtime = true, variable = RuntimeParamType.starting.train.arrival_direction},
            align_side = {runtime = true, variable = RuntimeParamType.starting.train.arrival_direction},
            ignore_locomotives = true,
            offset_num = {runtime = true, variable = RuntimeParamType.starting.train.wagon_count}
        })
        RSAD_Actions.decouple(1, false, {runtime = true, variable = RuntimeParamType.starting.train.arrival_direction})
        RSAD_Actions.leave_station()
        sets[rsad_station_type.empty_staging] = RSAD_Actions.close_set()
    elseif station_data.type == rsad_station_type.empty_pickup then
    end
    return sets
end






