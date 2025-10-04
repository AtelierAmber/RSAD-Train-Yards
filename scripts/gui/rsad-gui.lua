GLIB_CONFIG = {
  register_events = false,
  use_event_handler = false
} --[[@as Glib.Config]]
glib = require("__glib__.glib") --[[@as Glib]]
wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]

local builder = require("scripts.gui.lib.gui-builder")

local controller_gui = require("scripts.gui.definitions.controller-gui")

---@param event EventData.on_gui_click
local function click_mod_button(event)
  local frame, refs = glib.add(game.get_player(event.player_index).gui.screen, controller_gui)
  --if frame.construct then frame:construct() end
end

local mod_button = builder.button(rsad.controller.gui.names.mod_button, click_mod_button, { rsad.controller.gui.names.mod_button })
wrapper.new_mod_gui(mod_button)

glib.register_handlers(mod_button.handlers, nil, rsad.controller.gui.names.mod_button)
glib.register_handlers(controller_gui.handlers, nil, rsad.controller.gui.names.namespace)

local gui_handlers = {
  wrapper,
  glib,
}

return gui_handlers
