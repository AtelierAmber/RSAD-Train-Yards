---MARK: Sprites
data:extend({
  {
    type = "sprite",
    name = "orange-right-arrow",
    filename = "__core__/graphics/arrows/hint-orange-arrow-right.png",
    width = 38,
    height = 70,
    flags = {"gui"},
    usage = "player",
    scale = 0.5
  }
})

--MARK: GUI
local styles = data.raw["gui-style"]["default"]

styles.rsad_tabbed_pane_expanded_content = {
  type = "tabbed_pane_style",
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  tab_content_frame =
  {
    type = "frame_style",
    parent = "tabbed_pane_frame",
    use_header_filler = false,
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    horizontally_squashable = "off",
    vertically_squashable = "off",
    horizontal_flow_style = {
      type = "horizontal_flow_style",
      horizontally_stretchable = "on",
      vertically_stretchable = "on",
      horizontally_squashable = "off",
      vertically_squashable = "off",
    }
  }
}

styles.rsad_list_box = {
  type = "list_box_style",
  parent = "list_box_under_subheader",
  vertically_stretchable = "on",
  horizontally_stretchable = "on",
  scroll_pane_style = {
    type = "scroll_pane_style",
    parent = "list_box_in_shallow_frame_under_subheader_scroll_pane",
    vertical_flow_style =
    {
      type = "vertical_flow_style",
      vertical_spacing = 0,
      vertically_stretchable = "on",
      horizontally_stretchable = "on",
    },
    vertically_stretchable = "on",
    horizontally_stretchable = "on",
  }
}

array_tiling = deep_slot_background_tiling(64, 64) --[[@type data.ElementImageSet]]

styles.rsad_array_frame = {
  type = "frame_style",
  use_header_filler = false,
  horizontally_stretchable = "on",
  padding = 1,
  graphical_set = {
    base = {
      center = {position = {42, 8}, size = {1, 1}},
      border = 0,
      draw_type = "inner"
    }
  },
  background_graphical_set = array_tiling,
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0,
    top_padding = 4,
    left_padding = 0,
    right_padding = 0,
    bottom_padding = 0
  }
}

--- Unused
styles.rsad_procedure_array = {
  type = "scroll_pane_style",
  parent = "trains_scroll_pane",
  horizontally_stretchable = "stretch_and_expand",
  vertically_stretchable = "stretch_and_expand",
  vertical_flow_style =
  {
    type = "vertical_flow_style",
    vertical_spacing = 0,
    horizontally_stretchable = "on",
    vertically_stretchable = "on"
  },
  padding = 0,
  graphical_set = {
    base = {
      center = {position = {42, 8}, size = {1, 1}},
      border = 0,
      draw_type = "inner"
    }
  },
  background_graphical_set = array_tiling
}