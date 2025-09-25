GLIB_CONFIG = {
    register_events = false,
    use_event_handler = false
}--[[@as Glib.Config]]
glib = require("__glib__.glib") --[[@as Glib]]
wrapper = require("scripts.gui.overview-gui") --[[@as RSAD.GuiWrapper]]

--Testing
local builder = require("scripts.gui.lib.gui-builder")
wrapper.new_mod_gui(builder.button(names.mod_button, "show", {"", "GUI-SUX"}))
--=

local gui_handlers = {
    glib,
    wrapper,
}

return gui_handlers