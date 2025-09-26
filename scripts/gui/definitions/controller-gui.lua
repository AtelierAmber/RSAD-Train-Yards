require("scripts.gui.definitions.overview-gui")

rsad.controller.gui = {}
rsad.controller.gui.names = {
    namespace = "rsad-controller",
    mod_button = "mod-gui-button"
}
local builder = require("scripts.gui.lib.gui-builder")

--Main Frame
---@type RSAD.GuiBuilder
local main_frame = builder.make_window(rsad.controller.gui.names.namespace, {100,100}, true){
    builder.hflow(){
        builder.label("test")
    }
    --require("scripts.gui.definitions.overview-gui")
}

---@param event EventData.on_gui_click
local function click (event)
    glib.add(game.get_player(event.player_index).gui.screen, main_frame)
end
local mod_button = builder.button(rsad.controller.gui.names.mod_button, click, {"", "GUI-SUX"})
wrapper.new_mod_gui(mod_button)

glib.register_handlers(mod_button.handlers, nil, rsad.controller.gui.names.mod_button)
glib.register_handlers(main_frame.handlers, nil, rsad.controller.gui.names.namespace)