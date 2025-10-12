local create_yard_dialog = require("scripts.gui.definitions.dialogs.create-yard-dialog")
glib.register_handlers(create_yard_dialog.handlers)

local handlers = {}

---Closes the main window frame
---@param event EventData.on_gui_closed
function handlers.close_controller(event)
  local main_frame = event.element.gui.screen[rsad.gui.ref_names.main] --[[@as LuaGuiElement]]
  local player_state = rsad.gui.states[event.player_index]
  if main_frame then
    if player_state and player_state.open_dialog then
      glib.set_tag(event.element.gui.screen[player_state.open_dialog], "dialog_parent", rsad.gui.ref_names.main)
    else
      main_frame.destroy()
      rsad.gui.controller_refs = nil
    end
  end
end

---@param event GuiEventData
function handlers.open_create_yard(event)
  local player = game.get_player(event.player_index)
  if not player then error("No player found when opening create yard dialog!") end

  local player_state = rsad.gui.states[event.player_index]
  local elem, refs = glib.add(event.element.gui.screen, create_yard_dialog)

  if player_state then
    player_state.open_dialog = elem.name
  end

  player.opened = elem
end

return handlers