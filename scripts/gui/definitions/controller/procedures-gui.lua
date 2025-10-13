local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]


rsad.gui.procedures_tab = {}
rsad.gui.procedures_tab.ref_names = {
  procedures_list = "rsad_procedures_list",
  procedure_nodes = "procedure_nodes"
}

local handlers = require("scripts.gui.handlers.procedures-handlers")
local ref_names = rsad.gui.procedures_tab.ref_names

local procedures_tab = builder.hflow("rsad_procedures_tab", "inset_frame_container_horizontal_flow_in_tabbed_pane", {height = 700, maximal_height = 700, horizontally_stretchable = true}){
  builder.frame(nil, "deep_frame_in_shallow_frame", true, {width = 300}){ 
    builder.frame(nil, "slot_window_frame"){ 
      builder.hflow(nil, nil, {vertical_align = "center"}){
        builder.label({"rsad-controller-gui.procedures-list"}, nil, "heading_2_label"),
        builder.spacer(false, true),
        builder.button("create_procedure", handlers.open_create_procedure, "map_view_add_button", {"rsad-controller-gui.create"}),
      }
    },
    builder.list(ref_names.procedures_list, nil, 0, "rsad_list_box"),
  },
  builder.frame(nil, "rsad_array_frame", true){
    builder.hflow(){
      builder.button("delete_procedure", handlers.delete_procedure, "red_button", {"rsad-controller-gui.procedure-delete"}, nil, nil, {horizontal_align = "center", left_margin = 4}),
      builder.button("add_node", handlers.add_node, "rounded_button", {"rsad-controller-gui.procedure-add-node"}, nil, nil, {horizontal_align = "center"}),
      builder.spacer(false, true),
      builder.button("procedure_preview_train", handlers.select_train_preview, "target_station_in_schedule_in_train_view_list_box_item", {"rsad-controller-gui.procedure-no-preview"}, nil, nil, {right_margin = 2})
    },
    builder.hscroll(nil, "always", "naked_scroll_pane", {width = 1136 + (420 - 300), top_margin = -2, horizontally_stretchable = true, horizontally_squashable = false}){
      builder.hflow(ref_names.procedure_nodes, nil, {padding = 20, vertically_stretchable = true, horizontally_stretchable = true, vertical_align = "center"})
    }
  }
}

return procedures_tab