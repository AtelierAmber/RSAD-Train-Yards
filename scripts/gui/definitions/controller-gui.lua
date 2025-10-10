local handlers = require("scripts.gui.handlers.controller-handlers")
local builder = require("scripts.gui.lib.gui-builder")

rsad.controller.gui = {}
rsad.controller.gui.names = {
  namespace = "rsad-controller",
  mod_button = "rsad-controller-gui.mod-gui-button",
  frame_title = "rsad-controller-gui.frame-title",

  overview_tab_title = "rsad-controller-gui.overview-tab-title",
  logistics_tab_title = "rsad-controller-gui.logistics-tab-title",
  routine_tab_title = "rsad-controller-gui.routine-tab-title",
  procedure_tab_title = "rsad-controller-gui.procedure-tab-title",
}
local localised_names = rsad.controller.gui.names

--Main Frame
---@type RSAD.GuiBuilder
local main_frame = 
builder.frame(localised_names.namespace, "frame", true)
  :center()
  :with_construction(localised_names.namespace, function() end)
  :with_events({_closed = handlers.close_controller}) {
  builder.hflow(){
    builder.label({localised_names.frame_title}, nil, "frame_title"),
    builder.dragger("title.drag", localised_names.namespace, {minimal_height = 24}),
    builder.button("title.close", handlers.close_controller, "close_button", nil, nil, "utility/close")
  },
  builder.frame("tab_frame", "inside_deep_frame"){
    builder.tabbed_pane("main_tabs"){
      builder.pane_tab("overview_tab", {localised_names.overview_tab_title}){
        require("scripts.gui.definitions.overview-gui")
      },
      builder.pane_tab("logistics_tab", {localised_names.logistics_tab_title}){
        require("scripts.gui.definitions.logistics-gui")
      },
      builder.pane_tab("routine_tab", {localised_names.routine_tab_title}){
        require("scripts.gui.definitions.routines-gui")
      },
      builder.pane_tab("procedure_tab", {localised_names.procedure_tab_title}){
        require("scripts.gui.definitions.procedures-gui")
      },
    },
  }
}

return main_frame
