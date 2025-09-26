require("scripts.gui.definitions.overview-gui")

rsad.controller.gui = {}
rsad.controller.gui.names = {
    namespace = "rsad-overview-gui",
    mod_button = "mod-gui-button"
}
local builder = require("scripts.gui.lib.gui-builder")
glib.register_handlers(builder.default_handlers)

-- Need to move handlers to a compiled table from builder
local handlers = {}

---@param event EventData.on_gui_click
function handlers.click (event)
    glib.add(game.get_player(event.player_index).gui.screen, builder.make_window("test"))
end
wrapper.new_mod_gui(builder.button(names.mod_button, handlers.click, {"", "GUI-SUX"}))
glib.register_handlers(handlers)