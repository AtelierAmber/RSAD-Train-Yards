local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]


rsad.gui.routines_tab = {}
rsad.gui.routines_tab.ref_names = {
  main = "rsad_routines_tab",
}

local ref_names = rsad.gui.routines_tab.ref_names

local routines_tab = builder.hflow(ref_names.main, "inset_frame_container_horizontal_flow_in_tabbed_pane", {height = 700, maximal_height = 700}){
  builder.frame(nil, "deep_frame_in_shallow_frame", true, {width = 300}){ 
    builder.frame(nil, "slot_window_frame"){ 
      builder.hflow(nil, nil, {vertical_align = "center"}){
        builder.label({"rsad-controller-gui.routines-list"}, nil, "heading_2_label"),
        builder.spacer(false, true),
        builder.button("create_routine", nil, "map_view_add_button", {"rsad-controller-gui.create"}),
      }
    },
    builder.list("rsad_routines_list", nil, nil, 0, "rsad_list_box", {vertically_stretchable = true}),
  },
  builder.hscroll(nil, "always", "rsad_procedure_array", {width = 1136 + (420 - 300), horizontally_stretchable = true, horizontally_squashable = false}){
    builder.hflow("routine_nodes", nil, {padding = 20, vertically_stretchable = true, horizontally_stretchable = true, vertical_align = "center"})
  }
}

return routines_tab