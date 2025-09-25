GLIB_CONFIG = {
    register_events = false,
    use_event_handler = false
}--[[@as Glib.Config]]
glib = require("__glib__.glib") --[[@as Glib]]
wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]

--Testing

local names = {
    namespace = "rsad-overview-gui",
    mod_button = "mod-gui-button"
}
local builder = require("scripts.gui.lib.gui-builder")

-- Need to move handlers to a compiled table from builder
local handlers = {}
function handlers.click (event)
    glib.add(game.get_player(event.player_index).gui.screen, builder.make_window("test"))
end
wrapper.new_mod_gui(builder.button(names.mod_button, handlers.click, {"", "GUI-SUX"}))
glib.register_handlers(handlers)
--=

local gui_handlers = {
    glib,
    wrapper,
}

return gui_handlers