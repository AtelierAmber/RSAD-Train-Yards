local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]

local handlers = require("scripts.gui.handlers.overview-handlers")
local controller_handlers = require("scripts.gui.handlers.controller-handlers")

rsad.gui.overview_tab = {}
rsad.gui.overview_tab.ref_names = {
  yard_list = "rsad_overview_yard_list",
  yard_create = "rsad_overview_create_yard",
}
local ref_names = rsad.gui.overview_tab.ref_names

local overview_tab = builder.hflow("rsad_overview_content", "inset_frame_container_horizontal_flow_in_tabbed_pane", {height = 700, maximal_height = 700}){
  builder.frame(nil, "deep_frame_in_shallow_frame", true, {width = 420}){ 
    builder.frame(nil, "slot_window_frame"){ 
      builder.hflow(nil, nil, {vertical_align = "center"}){
        builder.label({"rsad-controller-gui.yard-list"}, nil, "heading_2_label"),
        builder.spacer(false, true),
        builder.button(ref_names.yard_create, controller_handlers.open_create_yard, "map_view_add_button", {"rsad-controller-gui.create"}, nil, nil),
      }
    },
    builder.list(ref_names.yard_list, nil, nil, 0, "rsad_list_box", {vertically_stretchable = true}),
  },
  builder.vscroll(nil, nil, "trains_scroll_pane"){
    builder.table(4, "rsad_overview_train_views", "trains_widget_table", nil, nil, 
      {vertically_stretchable = true, horizontally_stretchable = true})
  }
}
-- builder.hflow(nil, nil, {vertical_align = "center"}){
--   builder.checkbox("rsad_overview_filter_by_yard", false, nil),
--   builder.dropdown("rsad_overview_yard_selection", {"A", "B", "C"}),
-- }
return overview_tab