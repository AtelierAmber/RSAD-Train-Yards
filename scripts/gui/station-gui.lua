local rsad_controller = rsad_controller --- Find Global rsad_controller
assert(rsad_controller ~= nil)

flib_gui = require("__flib__.gui")
require("prototypes.names")
require("scripts.defines")
require("scripts.rsad.util")

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

---@class VisibilityToggles
---@field public item boolean
---@field public turnabout boolean

---@type table<uint, VisibilityToggles>
local modal_visibilities = {
    [rsad_station_type.turnabout] = { item = false, turnabout = true },
    [rsad_station_type.shunting_depot] = { item = false, turnabout = false },
    [rsad_station_type.request] = { item = true, turnabout = false },
    [rsad_station_type.import_staging] = { item = false, turnabout = false },
    [rsad_station_type.import] = { item = true, turnabout = false },
    [rsad_station_type.empty_staging] = { item = false, turnabout = false },
    [rsad_station_type.empty_pickup] = { item = false, turnabout = false },
}

---@param selected_type rsad_station_type
function set_modal_visibility(selected_type, mainscreen)
    --- Item signal
    mainscreen.frame.vflow_main.hflow_signals.vflow_item.visible = modal_visibilities[selected_type].item
    --- Subtype
    mainscreen.frame.vflow_main.vflow_subtype.visible = modal_visibilities[selected_type].turnabout
    mainscreen.frame.vflow_main.vflow_subtype.turnabout_type.visible = modal_visibilities[selected_type].turnabout
end

---@param e EventData.on_gui_selection_state_changed
function handle_type_drop_down(e)
	local element = e.element
	if not element then return end

    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

    local index = element.selected_index - 1

    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local circuit = control.circuit_condition
    if bit32.extract(circuit.constant, 0, 4) == index then return end 
    ---@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = index
    if index == rsad_station_type.turnabout then
---@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
        circuit.constant = bit32.replace(index, 1, 4, 4)
    end
    control.circuit_condition = circuit

    local station = rsad_controller.stations[unit_number]
    if station and entity.name ~= "entity-ghost" then

        local yard = rsad_controller:get_or_create_train_yard(control.stopped_train_signal)
        if yard then
            yard:add_or_update_station(station)
        end
    end

    update_rsad_station_name(entity, control, index)

    local player = game.get_player(e.player_index)
    if not player then return end
    player.opened.titlebar.titlebar_label.caption = {"", "RSAD ", {"rsad-gui.station-types.station-" .. index}, " Station"}

	set_modal_visibility(index, player.opened)
end

function handle_turnabout_drop_down(e)
    local element = e.element
	if not element then return end

    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

    local index = element.selected_index

    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local circuit = control.circuit_condition
    ---@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = bit32.replace(circuit.constant, index, 4, 4)
    control.circuit_condition = circuit

    local station = rsad_controller.stations[unit_number]
    if control.stopped_train_signal and station and entity.name ~= "entity-ghost" then
        local yard = rsad_controller:get_or_create_train_yard(control.stopped_train_signal)
        if yard then
            yard:add_or_update_station(station)
        end
    end

    update_rsad_station_name(entity, control, bit32.extract(circuit.constant, 0, 4))
end

---@param e EventData.on_gui_elem_changed
function handle_network(e)
	local element = e.element
	if not element then return end
    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

	local signal = element.elem_value --[[@as SignalID?]]
    if signal and entity.name ~= "entity-ghost" then
        local found, station = rsad_controller:get_or_create_station(entity, signal)
        if found and station then
            rsad_controller:migrate_station(station, signal)
        end
    end
end

---@param e EventData.on_gui_elem_changed
function handle_item(e)
	local element = e.element
	if not element then return end
    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

    if element.elem_value then
        --[[@type SignalID]]
        local signal = {}
        signal.name = element.elem_value --[[@as string]]
        local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
        control.priority_signal = signal
        ---@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.35
        update_rsad_station_name(entity, control, bit32.extract(control.circuit_condition.constant, 0, 4))

        local station = rsad_controller.stations[unit_number]
        if station and entity.name ~= "entity-ghost" then            
            local yard = rsad_controller:get_or_create_train_yard(control.stopped_train_signal)
            if yard then
                yard:add_or_update_station(station)
            end
        end
    end
end

---@param e EventData.on_gui_switch_state_changed
function handle_reversed(e)    
	local element = e.element
	if not element then return end
    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local circuit = control.circuit_condition
    local state_val = element.switch_state == "left" and 0 or 1

---@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = bit32.replace(circuit.constant, state_val, 8, 1)
    control.circuit_condition = circuit
end

---@param entity LuaEntity
---@param player LuaPlayer
---@param network SignalID?
---@param item SignalID?
---@param reversed boolean
---@return flib.GuiElemDef
function station_gui(entity, player, selected_index, network, item, reversed, subtype) return {
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
                    caption = {"", "RSAD ", {"rsad-gui.station-types.station-" .. selected_index}, " Station"},
                    elem_mods = { ignored_by_interaction = true },
                },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = { ignored_by_interaction = true } },
                {
                    type = "sprite-button",
                    style = "frame_action_button",
                    mouse_button_filter = { "left" },
                    sprite = "utility/close",
                    hovered_sprite = "utility/close",
                    name = "close_button",
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
                name = "vflow_main",
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
                    --Type drop down
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
                                    { "rsad-gui.station-types.station-0" },
                                    { "rsad-gui.station-types.station-1" },
                                    { "rsad-gui.station-types.station-2" },
                                    { "rsad-gui.station-types.station-3" },
                                    { "rsad-gui.station-types.station-4" },
                                    { "rsad-gui.station-types.station-5" },
                                    { "rsad-gui.station-types.station-6" },
                                },
                            }
                        },
                    },
                    ---Reversed Shunting switch
                    { type = "line", style_mods = { top_padding = 10 } },
                    {
                        type = "flow",
                        name = "vflow_switch",
                        direction = "vertical",
                        style_mods = {horizontal_align = "left"},
                        children = {
                            {
                                type = "label",
                                name = "switch_label",
                                style = "heading_2_label",
                                caption = {"rsad-gui.shunting-direction-switch"},
                                style_mods = {top_padding = 8}
                            },
                            {
                                type = "switch",
                                name = "shunting_direction_switch",
                                left_label_caption = {"rsad-gui.shunting-direction-switch-left"},
                                left_label_tooltip = {"rsad-gui.shunting-direction-switch-left-tooltip"},
                                right_label_caption = {"rsad-gui.shunting-direction-switch-right"},
                                right_label_tooltip = {"rsad-gui.shunting-direction-switch-right-tooltip"},
                                allow_none_state = false,
                                switch_state = reversed and "right" or "left",
                                handler = handle_reversed,
                                tags = { id = entity.unit_number },
                            }
                        }
                    },
                    ---Subtype section
                    {
                        type = "flow",
                        name = "vflow_subtype",
                        direction = "vertical",
                        style_mods = {horizontal_align = "center"},
                        children = {
                            { type = "line", style_mods = { top_padding = 10 } },
                            {
                                type = "flow",
                                name = "turnabout_type",
                                direction = "vertical",
                                style_mods = {horizontal_align = "left"},
                                children = {
                                    {
                                        type = "label",
                                        style = "heading_2_label",
                                        caption = { "rsad-gui.station-turnabout" }
                                    },
                                    {
                                        type = "drop-down",
                                        style_mods = { top_padding = 3, right_margin = 8 },
                                        handler = handle_turnabout_drop_down,
                                        tags = { id = entity.unit_number },
                                        selected_index = subtype,
                                        items = {
                                            { "rsad-gui.turnabout-phase.phase-1" },
                                            { "rsad-gui.turnabout-phase.phase-2" },
                                            { "rsad-gui.turnabout-phase.phase-3" },
                                        },
                                    }
                                }
                            }
                        }
                    },
                    ---Settings section for network
                    { type = "line", style_mods = { top_padding = 10 } },
                    {
                        type = "flow",
                        name = "hflow_signals",
                        direction = "horizontal",
                        style_mods = {horizontal_align = "center", vertical_align = "center"},
                        children = {
                            --Network
                            {
                                type = "flow",
                                name = "vflow_network",
                                direction = "vertical",
                                style_mods = {horizontal_align = "center"},
                                children = {
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
                                    }
                                }
                            },
                            { type = "line", direction = "vertical", style_mods = { top_padding = 10 } },
                            --Item
                            {
                                type = "flow",
                                name = "vflow_item",
                                direction = "vertical",
                                style_mods = {horizontal_align = "center"},
                                children = {
                                    {
                                        type = "label",
                                        name = "item_label",
                                        style = "heading_2_label",
                                        caption = { "rsad-gui.item" },
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
                                                name = "item",
                                                style = "slot_button_in_shallow_frame",
                                                elem_type = "item",
                                                tooltip = { "rsad-gui.item-tooltip" },
                                                item = (item and item.name),
                                                style_mods = { bottom_margin = 1, right_margin = 6, top_margin = 2 },
                                                handler = handle_item,
                                                tags = { id = entity.unit_number },
                                            },
                                        },
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
} end


---@param entity LuaEntity
---@return uint selected_type, SignalID? network, SignalID? item, uint subtype, boolean reversed
function get_station_gui_settings(entity)
    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    ---@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.35
    local constant = control.circuit_condition.constant
    local type = bit32.extract(constant, 0, 4)
    local subtype = bit32.extract(constant, 4, 4)
    local reversed = bit32.extract(constant, 8, 1)
	return  type + 1, control.stopped_train_signal, control.priority_signal, subtype, reversed == 1
end

function open_station_gui(rootgui, entity, player)
    local selected_type, network, item, subtype, reversed = get_station_gui_settings(entity)
    local _, mainscreen = flib_gui.add(rootgui, {station_gui(entity, player, selected_type, network, item, reversed, subtype)})
    mainscreen.frame.vflow_main.preview_frame.preview.entity = entity
    mainscreen.titlebar.drag_target = mainscreen
    mainscreen.titlebar.titlebar_label.caption = {"", "RSAD ", {"rsad-gui.station-types.station-" .. (selected_type-1)}, " Station"}
    mainscreen.force_auto_center()

    mainscreen.tags = {unit_number = entity.unit_number}
    set_modal_visibility(selected_type-1, mainscreen)
    player.opened = mainscreen
end

