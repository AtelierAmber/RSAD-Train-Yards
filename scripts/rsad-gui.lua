GLIB_CONFIG = {
    register_events = false,
    use_event_handler = false
}--[[@as Glib.Config]]
glib = require("__glib__.glib") --[[@as Glib]]
wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]

local controller = require("scripts.gui.definitions.controller-gui")

local gui_handlers = {
    wrapper,
    glib,
}

return gui_handlers