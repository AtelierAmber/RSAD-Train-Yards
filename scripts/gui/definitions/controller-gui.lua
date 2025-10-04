local handlers = require("scripts.gui.handlers.controller-handlers")
require("scripts.gui.definitions.overview-gui")

rsad.controller.gui = {}
rsad.controller.gui.names = {
  namespace = "rsad-controller",
  mod_button = "rsad-controller-gui.mod-gui-button"
}
local builder = require("scripts.gui.lib.gui-builder")

--Main Frame
---@type RSAD.GuiBuilder
local main_frame = 
builder.frame(rsad.controller.gui.names.namespace, "frame", false, {size = {600, 400}, use_header_filler = true}):center():with_construction(rsad.controller.gui.names.namespace, function() end) {
  builder.vflow(){
    builder.hflow(){
      builder.label("testasdasdasdasdasdasd"),
      builder.dragger("main-frame.drag", rsad.controller.gui.names.namespace, {minimal_height = 24}),
    },
    --require("scripts.gui.definitions.overview-gui"),
    builder.tabbed_pane("testtabbedpane"){
      builder.tab("testtab1"){
        builder.frame("testtabframe1")
      },
      builder.tab("testtab2"){
        builder.frame("testtabframe2")
      },
      builder.tab("testtab3"){
        builder.frame("testtabframe3")
      },
    },
  }
}

return main_frame
