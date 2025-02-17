flib_gui = require("__flib__.gui")
require("prototypes.names")


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

	local entity = game.get_entity_by_unit_number(element.tags.id)
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

---@param entity LuaEntity
---@param player LuaPlayer
---@return flib.GuiElemDef
function station_gui(entity, player) return {
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
                    caption = {"", "RSAD ", {entity.name}, " Station - " },
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
                                caption = { "status" }
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
                        caption = { "operation" },
                        style_mods = { top_padding = 8 }
                    }
                }
            }
        }
    }
} end

function open_station_gui(rootgui, entity, player)
    local _, main_frame = flib_gui.add(rootgui, {station_gui(entity, player)})
    main_frame.frame.vflow.preview_frame.preview.entity = entity
    main_frame.titlebar.drag_target = main_frame
    main_frame.force_auto_center()

    main_frame.tags = {unit_number = entity.unit_number}
    player.opened = main_frame
end

