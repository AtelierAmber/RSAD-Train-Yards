local rsad_controller = rsad_controller --- Find Global rsad_controller
assert(rsad_controller ~= nil)

flib_gui = require("__flib__.gui")
flib_math = require("__flib__.math")
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

local max_train_limit = settings.startup["rsad-station-max-train-limit"].value
local max_cargo_limit = settings.startup["rsad-station-max-cargo-limit"].value

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
---@field public direction boolean
---@field public turnabout boolean 
---@field public cargo boolean

---@type table<uint, VisibilityToggles>
local modal_visibilities = {
    [rsad_station_type.turnabout] = { item = false, direction = false, turnabout = true, cargo = false },
    [rsad_station_type.shunting_depot] = { item = false,  direction = false, turnabout = false, cargo = false },
    [rsad_station_type.request] = { item = true,  direction = true, turnabout = false, cargo = true },
    [rsad_station_type.import_staging] = { item = false,  direction = true, turnabout = false, cargo = true },
    [rsad_station_type.import] = { item = true,  direction = true, turnabout = false, cargo = true },
    [rsad_station_type.empty_staging] = { item = false,  direction = true, turnabout = false, cargo = true },
    [rsad_station_type.empty_pickup] = { item = false,  direction = true, turnabout = false, cargo = false },
}

---@param selected_type rsad_station_type
function set_modal_visibility(selected_type, mainscreen)
    if not modal_visibilities[selected_type] then return end
    --- Item signal
    mainscreen.frame.vflow_main.hflow_item.visible = modal_visibilities[selected_type].item
    --- Subtype
    mainscreen.frame.vflow_main.vflow_subtype.visible = modal_visibilities[selected_type].turnabout
    ---mainscreen.frame.vflow_main.vflow_subtype.turnabout_type.visible = modal_visibilities[selected_type].turnabout
    --- Cargo
    mainscreen.frame.vflow_main.vflow_cargo_limit.visible = modal_visibilities[selected_type].cargo
    --- Shunting Switch
    mainscreen.frame.vflow_main.hflow_switch.visible = modal_visibilities[selected_type].direction
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
    if bit32.extract(circuit.constant, STATION_TYPE_ID, STATION_TYPE_ID_WIDTH) == index then return end 
    ------@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = bit32.replace(circuit.constant, index, STATION_TYPE_ID, STATION_TYPE_ID_WIDTH)
    control.circuit_condition = circuit

    local station = rsad_controller.stations[unit_number]
    if station and entity.name ~= "entity-ghost" then

        local yard = rsad_controller:get_or_create_train_yard(control.stopped_train_signal)
        if yard then
            yard:add_or_update_station(station)
        end
    end

    update_rsad_station_name(entity, control, index)

    local mainscreen = element.parent.parent.parent.parent --[[@as LuaGuiElement]]
    mainscreen.titlebar.titlebar_label.caption = {"", "RSAD ", {"rsad-gui.station-types.station-" .. index}, " Station"}

	set_modal_visibility(index, mainscreen)
end

function handle_turnabout_drop_down(e)
    local element = e.element
	if not element then return end
    local index = element.selected_index
    if index == 0 then return end

    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local circuit = control.circuit_condition
    ------@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = bit32.replace(circuit.constant, index, STATION_SUBINFO, STATION_SUBINFO_WIDTH)
    control.circuit_condition = circuit

    local station = rsad_controller.stations[unit_number]
    if control.stopped_train_signal and station and entity.name ~= "entity-ghost" then
        local yard = rsad_controller:get_or_create_train_yard(control.stopped_train_signal)
        if yard then
            yard:add_or_update_station(station)
        end
    end

    update_rsad_station_name(entity, control, bit32.extract(circuit.constant, STATION_TYPE_ID, STATION_TYPE_ID_WIDTH))
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
        local _, station = rsad_controller:get_or_create_station(entity, signal)
        if station then
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
        if element.elem_type == "fluid" then signal.type = "fluid" signal.name = element.elem_value --[[@as string]]
        elseif element.elem_type == "item" then
            signal.name = element.elem_value --[[@as string]]
        else
            signal = element.elem_value --[[@as SignalID?]]
        end
        local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
        control.priority_signal = signal
        ------@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.35
        update_rsad_station_name(entity, control, bit32.extract(control.circuit_condition.constant, STATION_TYPE_ID, STATION_TYPE_ID_WIDTH))

        local station = rsad_controller.stations[unit_number]
        if station and entity.name ~= "entity-ghost" then            
            local yard = rsad_controller:get_or_create_train_yard(control.stopped_train_signal)
            if yard then
                yard:add_or_update_station(station)
            end
        end
    end
end

---@param e EventData.on_gui_elem_changed
function handle_item_switch(e)
	local element = e.element
	if not element then return end

    if element.switch_state == "left" then
        element.parent.buttons.item.visible = true
        element.parent.buttons.fluid.visible = false
        element.parent.buttons.all.visible = false
    elseif element.switch_state == "right" then
        element.parent.buttons.item.visible = false
        element.parent.buttons.fluid.visible = true
        element.parent.buttons.all.visible = false
    else
        element.parent.buttons.item.visible = false
        element.parent.buttons.fluid.visible = false
        element.parent.buttons.all.visible = true
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
    circuit.constant = bit32.replace(circuit.constant, state_val, SHUNTING_DIRECTION, SHUNTING_DIRECTION_WIDTH)
    control.circuit_condition = circuit
end

---@param e EventData.on_gui_value_changed|EventData.on_gui_text_changed
function handle_train_limit(e)
    local element = e.element
	if not element then return end
    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

    if element.type == "slider" then
        local value = flib_math.clamp(element.slider_value, 1, max_train_limit)
        entity.trains_limit = value
        element.parent.number_field.text = tostring(entity.trains_limit)
    else
        local value = flib_math.clamp(tonumber(element.text), 1, max_train_limit)
        entity.trains_limit =  value
        element.text = tostring(value)
        element.parent.slider.slider_value = entity.trains_limit
    end
end

function handle_cargo_limit(e)
    local element = e.element
	if not element then return end

    local unit_number = element.tags.id --[[@as uint]]
	local entity = game.get_entity_by_unit_number(unit_number)
	if not entity or not entity.valid then return end

    local limit = 1
    if element.type == "slider" then
        local value = flib_math.clamp(element.slider_value, 1, max_cargo_limit)
        limit = value
        element.parent.number_field.text = tostring(limit)
    else
        local value = flib_math.clamp(tonumber(element.text), 1, max_cargo_limit)
        limit =  value
        element.text = tostring(value)
        element.parent.slider.slider_value = limit
    end

    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local circuit = control.circuit_condition
    ------@diagnostic disable-next-line: undefined-field, inject-field --- CircuitCondition Changed v2.0.35
    circuit.constant = bit32.replace(circuit.constant, limit, STATION_SUBINFO, STATION_SUBINFO_WIDTH)
    control.circuit_condition = circuit
end

local status_gui = {
    type = "flow",
    style = "flib_titlebar_flow",
    direction = "horizontal",
    style_mods = {
        vertical_align = "center",
        horizontally_stretchable = true,
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
}

local preview_gui = {
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
}

---@param entity LuaEntity
local function type_gui_drop_down(entity, selected_index) return {
    type = "flow",
    name = "type_gui",
    direction = "horizontal",
    style = "player_input_horizontal_flow",
    children = {
        {
            type = "label",
            style = "label",
            caption = { "rsad-gui.station-type" },
        },
        {
            type = "empty-widget",
            style_mods = {horizontally_stretchable = true,}
        },
        {
            type = "drop-down",
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
} end
---@param entity LuaEntity
---@param reversed boolean
local function shunting_switch(entity, reversed) return {
    type = "flow",
    name = "hflow_switch",
    direction = "horizontal",
    style = "player_input_horizontal_flow",
    style_mods = { vertical_align = "center", horizontal_align = "left" },
    children = {
        {
            type = "label",
            name = "switch_label",
            style = "label",
            caption = {"rsad-gui.shunting-direction-switch"},
        },
        {
            type = "empty-widget",
            style_mods = {horizontally_stretchable = true,}
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
} end
---@param entity LuaEntity
---@param subinfo integer
local function subtype_drop_down(entity, subinfo) return {
    type = "flow",
    name = "vflow_subtype",
    direction = "vertical",
    style_mods = {horizontal_align = "left"},
    children = {
        {
            type = "flow",
            name = "turnabout_type",
            direction = "horizontal",
            style = "player_input_horizontal_flow",
            style_mods = {horizontal_align = "left"},
            children = {
                {
                    type = "label",
                    style = "label",
                    caption = { "rsad-gui.station-turnabout" }
                },
                {
                    type = "empty-widget",
                    style_mods = {horizontally_stretchable = true,}
                },
                {
                    type = "drop-down",
                    style_mods = { },
                    handler = handle_turnabout_drop_down,
                    tags = { id = entity.unit_number },
                    selected_index = ((subinfo >= rsad_shunting_stage.sort_imports and subinfo < rsad_shunting_stage.return_to_depot) and subinfo) or 0,
                    items = {
                        { "rsad-gui.turnabout-phase.phase-1" },
                        { "rsad-gui.turnabout-phase.phase-2" },
                        { "rsad-gui.turnabout-phase.phase-3" },
                    },
                }
            }
        }
    }
} end
---@param entity LuaEntity
local function train_limit_bar(entity) return {
    type = "flow",
    name = "vflow_train_limit",
    direction = "vertical",
    style_mods = {horizontal_align = "left"},
    children = {
        {
            type = "flow",
            name = "train_limit",
            direction = "horizontal",
            style = "player_input_horizontal_flow",
            style_mods = {vertical_align = "center"},
            children = {
                {
                    type = "label",
                    style = "label",
                    caption = { "rsad-gui.station-train-limit" }
                },
                {
                    type = "empty-widget",
                    style_mods = {horizontally_stretchable = true,}
                },
                {
                    type = "slider",
                    style = "notched_slider",
                    name = "slider",
                    handler = handle_train_limit,
                    tags = { id = entity.unit_number },
                    value = entity.trains_limit,
                    minimum_value = 1,
                    maximum_value = max_train_limit
                },
                {
                    type = "textfield",
                    name = "number_field",
                    style_mods = { width = 35},
                    handler = handle_train_limit,
                    tags = { id = entity.unit_number },
                    text = tostring(entity.trains_limit),
                    numeric = true
                }
            }
        }
    }
} end
---@param entity LuaEntity
---@param subinfo integer
local function cargo_limit_bar(entity, subinfo) return {
    type = "flow",
    name = "vflow_cargo_limit",
    direction = "vertical",
    style_mods = {horizontal_align = "left"},
    children = {
        {
            type = "flow",
            name = "cargo_limit",
            direction = "horizontal",
            style = "player_input_horizontal_flow",
            style_mods = {vertical_align = "center"},
            children = {
                {
                    type = "label",
                    style = "label",
                    caption = { "rsad-gui.station-cargo-limit" }
                },
                {
                    type = "empty-widget",
                    style_mods = {horizontally_stretchable = true,}
                },
                {
                    type = "slider",
                    style = "notched_slider",
                    name = "slider",
                    handler = handle_cargo_limit,
                    tags = { id = entity.unit_number },
                    value = subinfo,
                    minimum_value = 1,
                    maximum_value = max_train_limit
                },
                {
                    type = "textfield",
                    name = "number_field",
                    style_mods = { width = 35},
                    handler = handle_cargo_limit,
                    tags = { id = entity.unit_number },
                    text = tostring(subinfo),
                    numeric = true
                }
            }
        }
    }
} end
---@param entity LuaEntity
---@param network SignalID?
local function network_selection(entity, network) return {
    type = "flow",
    name = "hflow_network",
    direction = "horizontal",
    style = "player_input_horizontal_flow",
    children = {
        {
            type = "label",
            name = "network_label",
            style = "label",
            caption = { "rsad-gui.network" },
            style_mods = { },
        },
        {
            type = "empty-widget",
            style_mods = {horizontally_stretchable = true,}
        },
        {
            type = "choose-elem-button",
            name = "network",
            style = "slot_button_in_shallow_frame",
            elem_type = "signal",
            tooltip = { "rsad-gui.network-tooltip" },
            signal = network,
            style_mods = { },
            handler = handle_network,
            tags = { id = entity.unit_number },
        },
    }
} end
---@param entity LuaEntity
---@param item SignalID?
---@param switch string
local function item_selection(entity, item, switch) return {
    type = "flow",
    name = "hflow_item",
    direction = "horizontal",
    style = "player_input_horizontal_flow",
    style_mods = {width = 400},
    children = {
        {
            type = "label",
            name = "item_label",
            style = "label",
            caption = { "rsad-gui.item" },
            style_mods = { },
        },
        {
            type = "empty-widget",
            style_mods = {horizontally_stretchable = true,}
        },
        {
            type = "switch",
            name = "item_request_switch",
            left_label_caption = { "rsad-gui.item-switch-left" },
            left_label_tooltip = { "rsad-gui.item-switch-left-tooltip" },
            right_label_caption = { "rsad-gui.item-switch-right" },
            right_label_tooltip = { "rsad-gui.item-switch-right-tooltip" },
            tooltip = { "rsad-gui.item-switch-tooltip" },
            allow_none_state = true,
            switch_state = switch,
            handler = handle_item_switch,
        },
        {
            type = "flow",
            name = "buttons",
            direction = "horizontal",
            style_mods = { vertical_align = "top" },
            children = {
                {
                    type = "choose-elem-button",
                    name = "item",
                    style = "slot_button_in_shallow_frame",
                    elem_type = "item",
                    tooltip = { "rsad-gui.item-tooltip" },
                    item = ((item and not item.type) and item.name) or nil,
                    style_mods = { },
                    handler = handle_item,
                    tags = { id = entity.unit_number },
                    visible = switch == "left"
                },
                {
                    type = "choose-elem-button",
                    name = "fluid",
                    style = "slot_button_in_shallow_frame",
                    elem_type = "fluid",
                    tooltip = { "rsad-gui.item-tooltip" },
                    fluid = ((item and item.type == "fluid") and item.name) or nil,
                    style_mods = {  },
                    handler = handle_item,
                    tags = { id = entity.unit_number },
                    visible = switch == "right"
                },
                {
                    type = "choose-elem-button",
                    name = "all",
                    style = "slot_button_in_shallow_frame",
                    elem_type = "signal",
                    tooltip = { "rsad-gui.item-tooltip" },
                    signal = item,
                    style_mods = {  },
                    handler = handle_item,
                    tags = { id = entity.unit_number },
                    visible = switch == "none"
                },
            },
        }
    }
}end

---@param entity LuaEntity
---@param player LuaPlayer
---@param selected_index integer
---@param network SignalID?
---@param item SignalID?
---@param reversed boolean
---@param subinfo integer
---@param item_switch string
---@return flib.GuiElemDef
function station_gui(entity, player, selected_index, network, item, reversed, subinfo, item_switch) return {
    type = "frame",
    direction = "vertical",
    name = names.gui.rsad_station,
    style_mods = {width = 448},
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
                style_mods = { horizontal_align = "left", vertical_spacing = 8 },
                children = {
                    --status
                    status_gui,
                    --preview
                    preview_gui,
                    --Type drop down
                    type_gui_drop_down(entity, selected_index),
                    --Network
                    network_selection(entity, network),
                    { type = "line" },
                    {type = "label", style = "caption_label", name = "settings_label", caption = {"rsad-gui.settings-label"}},
                    ---Reversed Shunting switch
                    shunting_switch(entity, reversed),
                    ---Subtype section
                    subtype_drop_down(entity, subinfo),
                    ---Train Limit slider
                    train_limit_bar(entity),
                    ---Cargo Limit slider
                    cargo_limit_bar(entity, subinfo),
                    --Item
                    item_selection(entity, item, item_switch)
                }
            }
        }
    }
} end


---@param entity LuaEntity
---@return uint selected_type, SignalID? network, SignalID? item, uint subinfo, boolean reversed
function get_station_gui_settings(entity)
    local control = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    ------@diagnostic disable-next-line: undefined-field --- CircuitCondition Changed v2.0.35
    local constant = control.circuit_condition.constant or 0
    local type = bit32.extract(constant, STATION_TYPE_ID, STATION_TYPE_ID_WIDTH)
    local subinfo = bit32.extract(constant, STATION_SUBINFO, STATION_SUBINFO_WIDTH)
    local reversed = bit32.extract(constant, SHUNTING_DIRECTION, SHUNTING_DIRECTION_WIDTH)
	return  type + 1, control.stopped_train_signal, control.priority_signal, subinfo, reversed == 1
end

function open_station_gui(rootgui, entity, player)
    local selected_type, network, item, subinfo, reversed = get_station_gui_settings(entity)
    local item_switch = (item and (((item.type == "fluid") and "right") or (not item.type and "left"))) or "none" 
    local _, mainscreen = flib_gui.add(rootgui, {station_gui(entity, player, selected_type, network, item, reversed, subinfo, item_switch)})
    mainscreen.frame.vflow_main.preview_frame.preview.entity = entity
    mainscreen.titlebar.drag_target = mainscreen
    mainscreen.titlebar.titlebar_label.caption = {"", "RSAD ", {"rsad-gui.station-types.station-" .. (selected_type-1)}, " Station"}
    mainscreen.force_auto_center()

    mainscreen.tags = {unit_number = entity.unit_number}
    set_modal_visibility(selected_type-1, mainscreen)
    player.opened = mainscreen
end

