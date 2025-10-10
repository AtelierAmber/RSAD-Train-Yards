local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]

local handlers = require("scripts.gui.handlers.procedures-handlers")

rsad.controller.gui.procedures_tab = {}
rsad.controller.gui.procedures_tab.names = {
  routine_list_label = "rsad-controller-gui.procedures-list",
  routine_create = "rsad-controller-gui.procedure-create",
}
rsad.controller.gui.procedures_tab.state = {
  selected_routine = 1
}

local localised_names = rsad.controller.gui.procedures_tab.names
local state = rsad.controller.gui.procedures_tab.state

local procedures_tab = builder.hflow("rsad_routines_tab", "inset_frame_container_horizontal_flow_in_tabbed_pane"){
  builder.frame(nil, "deep_frame_in_shallow_frame", true, {width = 300}){ 
    builder.frame(nil, "slot_window_frame"){ 
      builder.hflow(nil, nil, {vertical_align = "center"}){
        builder.label({localised_names.routine_list_label}, nil, "heading_2_label"),
        builder.spacer(false, true),
        builder.button("create_routine", handlers.create_train_yard, "map_view_add_button", {localised_names.routine_create}),
      }
    },
    builder.list("rsad_routines_yardlist", {"A", "B", "C"}, state.selected_routine, nil, {vertically_stretchable = true}),
  },
  builder.frame(nil, "invisible_frame", false){
    builder.hscroll(nil, nil, "trains_scroll_pane", {width = 1400}){
      builder.hflow("routine_nodes", nil, {padding = 20, vertically_stretchable = true, horizontally_stretchable = true, vertical_align = "center"})
    }
  }
}

return procedures_tab