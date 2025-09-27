require("scripts.gui.definitions.overview-gui")

rsad.controller.gui = {}
rsad.controller.gui.names = {
  namespace = "rsad-controller",
  mod_button = "mod-gui-button"
}
local builder = require("scripts.gui.lib.gui-builder")

--Main Frame
---@type RSAD.GuiBuilder
local main_frame = builder.frame(rsad.controller.gui.names.namespace, "frame", false, {size = {300, 200}, use_header_filler = false}):center() {
  builder.label("test"),
  builder.spacer(false, true, "main-frame.drag", "draggable_space_header", {minimal_width = 200, minimal_height = 24})
  --require("scripts.gui.definitions.overview-gui")
}

---@param event EventData.on_gui_click
local function click(event)
  local frame, refs = glib.add(game.get_player(event.player_index).gui.screen, main_frame)
  refs["main-frame.drag"].drag_target = refs[rsad.controller.gui.names.namespace]
end
local mod_button = builder.button(rsad.controller.gui.names.mod_button, click, { "", "GUI-SUX" })
wrapper.new_mod_gui(mod_button)

glib.register_handlers(mod_button.handlers, nil, rsad.controller.gui.names.mod_button)
glib.register_handlers(main_frame.handlers, nil, rsad.controller.gui.names.namespace)
