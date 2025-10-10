local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]

local handlers = require("scripts.gui.handlers.overview-handlers")

rsad.controller.gui.overview_tab = {}
rsad.controller.gui.overview_tab.names = {
  yard_list_label = "rsad-controller-gui.yard-list",
  yard_create = "rsad-controller-gui.yard-create",
}
rsad.controller.gui.overview_tab.state = {
  selected_yard = 1
}
local localised_names = rsad.controller.gui.overview_tab.names
local state = rsad.controller.gui.overview_tab.state

local function get_yard_names()
  local names = {}
  for _, yard in pairs(rsad.controller.train_yards) do
    table.insert(names, yard.name)
  end
  return names
end

local overview_tab = builder.hflow("rsad_logistics_tab", "inset_frame_container_horizontal_flow_in_tabbed_pane"){
  builder.frame(nil, "deep_frame_in_shallow_frame", true, {width = 420}){ 
    builder.frame(nil, "slot_window_frame"){ 
      builder.hflow(nil, nil, {vertical_align = "center"}){
        builder.label({localised_names.yard_list_label}, nil, "heading_2_label"),
        builder.spacer(false, true),
        builder.button("rsad_logistics_create_yard", handlers.create_train_yard, "map_view_add_button", {localised_names.yard_create}, nil, nil),
      }
    },
    builder.list("rsad_logistics_yard_list", get_yard_names(), state.selected_yard, nil, {vertically_stretchable = true}),
  },
  -- builder.vscroll("train_scroll", nil, "trains_scroll_pane"){
  --   builder.table(4, "train_views", "trains_widget_table", nil, nil, 
  --     {width = 1200, vertically_stretchable = true, horizontally_stretchable = true})
  -- }
}

return overview_tab