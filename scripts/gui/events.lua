require("scripts.gui.station-gui")

---@param event EventData.on_gui_opened
local function on_gui_opened(event)
	local entity = event.entity
	if not entity or not entity.valid then return end

	local name = (entity.name == "entity-ghost" and entity.ghost_name) or entity.name
	if name ~= names.entities.rsad_station then return end

	local player = game.get_player(event.player_index)
	if not player then return end

    open_station_gui(player.gui.screen, entity, player)
end

---@param event EventData.on_gui_closed
local function on_gui_closed(event)
	local element = event.element
	if not element or element.name ~= names.gui.rsad_station then return end
	local entity = event.entity
	local is_ghost = entity and entity.name == "entity-ghost"
	local player = game.get_player(event.player_index)
	if not player then return end
	local rootgui = player.gui.screen

	if rootgui[names.gui.rsad_station] then
		rootgui[names.gui.rsad_station].destroy()
		if not is_ghost then
			--player.play_sound({ path = COMBINATOR_CLOSE_SOUND })
		end
	end
end

flib_gui.add_handlers({
	["rsad-station-close"] = handle_close,
	["rsad-station-type"] = handle_type_drop_down,
	["rsad-station-network"] = handle_network,
	["rsad-station-item-switch"] = handle_item_switch,
	["rsad-station-item"] = handle_item,
	["rsad-station-shunting-direction"] = handle_reversed,
	["rsad-station-turnabout"] = handle_turnabout_drop_down,
	["rsad-station-train-limit"] = handle_train_limit,
	["rsad-station-cargo-limit"] = handle_cargo_limit,
})
flib_gui.handle_events()

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
