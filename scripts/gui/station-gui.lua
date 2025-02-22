flib_gui = require("__flib__.gui")
require("prototypes.names")
require("scripts.defines")
require("scripts.rsad.rsad-controller")

local RED = "utility/status_not_working"
local GREEN = "utility/status_working"
local YELLOW = "utility/status_yellow"

local STATUS_SPRITES = {}
STATUS_SPRITES[defines.entity_status.working] = GREEN
STATUS_SPRITES[defines.entity_status.normal] = GREEN
STATUS_SPRITES[defines.entity_status.no_power] = RED
STATUS_SPRITES[defines.entity_status.low_power] = YELLOW
STATUS_SPRITES[defines.entity_status.disabled_by_control_behavior] = RED
STATUS_SPRITES[defines.entity_status.disabled_by_script] = RED
STATUS_SPRITES[defines.entity_status.marked_for_deconstruction] = RED
local STATUS_SPRITES_DEFAULT = RED
local STATUS_SPRITES_GHOST = YELLOW

local gui_ref

---@param e EventData.on_gui_click
function handle_close(e)
    local element = e.element
	if not element then return end

	local entity = game.get_entity_by_unit_number(element.tags.id --[[@as uint]])
	if not entity or not entity.valid then return end

	local player = game.get_player(e.player_index)
	if not player then return end
	local rootgui = player.gui.screen

	if rootgui[names.gui.rsad_station] then
		rootgui[names.gui.rsad_station].destroy()
		if entity.name ~= "entity-ghost" then
			--player.play_sound({ path = COMBINATOR_CLOSE_SOUND })
		end
	end
end

---@param e EventData.on_gui_selection_state_changed
function handle_type_drop_down(e)
	local element = e.element
	if not element then return end

    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

    local station = rsad_controller.stations[unit_number]
    local control = entity.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    local params = control.parameters
    params.operation = rsad_index_station[element.selected_index]
    control.parameters = params
    gui_ref.titlebar.titlebar_label.caption = {"", "RSAD ", {"rsad-gui.station-types.station-" .. rsad_index_station[element.selected_index]}, " Station"}
    if station then
        local success, data = station:data()
        if not success or not data then return end

        local yard = get_or_create_train_yard(data.network)
        if yard then
            yard:add_or_update_station(station)
        end
    end
	--set_visibility(element.parent.parent.parent.parent, element.selected_index)
end

---@param e EventData.on_gui_elem_changed
function handle_network(e)
	local element = e.element
	if not element then return end
    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

	local signal = element.elem_value --[[@as SignalID]]
    if signal then
        local found, station = get_or_create_station(entity, signal)
        if found and station then
            migrate_station(station, signal)
        end
    end
end

---@param entity LuaEntity
---@param player LuaPlayer
---@param network SignalID?
---@return flib.GuiElemDef
function station_gui(entity, player, selected_index, network) return {
    type = "frame",
    direction = "vertical",
    name = names.gui.rsad_station,
    children = {
        {
            type = "flow",
            name = "titlebar",
            children = {
                {
                    type = "label",
                    style = "frame_title",
                    name = "titlebar_label",
                    caption = {"", "RSAD ", {"rsad-gui.station-types.station-" .. rsad_index_station[selected_index]}, " Station"},
                    elem_mods = { ignored_by_interaction = true },
                },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = { ignored_by_interaction = true } },
                {
                    type = "sprite-button",
                    style = "frame_action_button",
                    mouse_button_filter = { "left" },
                    sprite = "utility/close",
                    hovered_sprite = "utility/close",
                    name = names.gui.rsad_station,
                    handler = handle_close,
                    tags = { id = entity.unit_number },
                },
            },
        },
        {
            type = "frame",
            name = "frame",
            direction = "vertical",
            style = "inside_shallow_frame_with_padding",
            style_mods = { padding = 12, bottom_padding = 9 },
            children = {
                type = "flow",
                name = "vflow",
                direction = "vertical",
                style_mods = { horizontal_align = "left" },
                children = {
                    --status
                    {
                        type = "flow",
                        style = "flib_titlebar_flow",
                        direction = "horizontal",
                        style_mods = {
                            vertical_align = "center",
                            horizontally_stretchable = true,
                            bottom_padding = 4,
                        },
                        children = {
                            {
                                type = "sprite",
                                sprite = STATUS_SPRITES[defines.entity_status.normal] or STATUS_SPRITES_DEFAULT,
                                style = "status_image",
                                style_mods = { stretch_image_to_widget_size = true },
                            },
                            {
                                type = "label",
                                caption = { "rsad-gui.status" }
                            },
                        },
                    },
                    --preview
                    {
                        type = "frame",
                        name = "preview_frame",
                        style = "deep_frame_in_shallow_frame",
                        style_mods = {
                            minimal_width = 0,
                            horizontally_stretchable = true,
                            padding = 0,
                        },
                        children = {
                            { type = "entity-preview", name = "preview", style = "wide_entity_button" },
                        },
                    },
                    --drop down
                    {
                        type = "label",
                        style = "heading_2_label",
                        caption = { "rsad-gui.station-type" },
                        style_mods = { top_padding = 8 }
                    },
                    {
                        type = "flow",
                        name = "top",
                        direction = "horizontal",
                        style_mods = { vertical_align = "center" },
                        children = {
                            {
                                type = "drop-down",
                                style_mods = { top_padding = 3, right_margin = 8 },
                                handler = handle_type_drop_down,
                                tags = { id = entity.unit_number },
                                selected_index = selected_index,
                                items = {
                                    { "rsad-gui.station-types.station-*" },
                                    { "rsad-gui.station-types.station-/" },
                                    { "rsad-gui.station-types.station-+" },
                                    { "rsad-gui.station-types.station-<<" },
                                    { "rsad-gui.station-types.station->>" },
                                    { "rsad-gui.station-types.station--" },
                                    { "rsad-gui.station-types.station-^" },
                                },
                            }
                        },
                    },
                    ---Settings section for network
                    { type = "line", style_mods = { top_padding = 10 } },
                    {
                        type = "label",
                        name = "network_label",
                        style = "heading_2_label",
                        caption = { "rsad-gui.network" },
                        style_mods = { top_padding = 8 },
                    },
                    {
                        type = "flow",
                        name = "bottom",
                        direction = "horizontal",
                        style_mods = { vertical_align = "top" },
                        children = {
                            {
                                type = "choose-elem-button",
                                name = "network",
                                style = "slot_button_in_shallow_frame",
                                elem_type = "signal",
                                tooltip = { "rsad-gui.network-tooltip" },
                                signal = network,
                                style_mods = { bottom_margin = 1, right_margin = 6, top_margin = 2 },
                                handler = handle_network,
                                tags = { id = entity.unit_number },
                            },
                        },
                    },
                }
            }
        }
    }
} end

---@param entity LuaEntity
---@return uint selected_type, SignalID? network, uint 
function get_station_gui_settings(entity)
    local params = entity.get_or_create_control_behavior().parameters --[[@as ArithmeticCombinatorParameters]]
	return rsad_station_index[params.operation], params.first_signal, 0
end

function open_station_gui(rootgui, entity, player)
    local selected_type, network, subtype = get_station_gui_settings(entity)
    local _, mainscreen = flib_gui.add(rootgui, {station_gui(entity, player, selected_type, network)})
    gui_ref = mainscreen
    gui_ref.frame.vflow.preview_frame.preview.entity = entity
    gui_ref.titlebar.drag_target = gui_ref
    gui_ref.force_auto_center()

    gui_ref.tags = {unit_number = entity.unit_number}
    player.opened = gui_ref
end

