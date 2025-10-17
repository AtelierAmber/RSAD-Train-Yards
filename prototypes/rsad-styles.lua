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

--- Text Box
styles.rsad_editable_label = {
  type = "textbox_style",
  ignored_by_search = false,
  default_background =
  {
    base = {position = {282, 0}, corner_size = 8},
    opacity = 0.5
  },
  font_color = gui_color.caption,
  left_padding = 8,
  right_padding = 2,
  top_padding = 0,
  bottom_padding = 0,
  width = 180,
  minimal_width = 0,
  horizontally_stretchable = "on",

  disabled_font_color = util.premul_color {1, 1, 1, 0.5},
  game_controller_hovered_background =
  {
    base = {position = {265, 0}, corner_size = 8},
    shadow = default_inner_shadow
  },
  disabled_background =
  {
    base = {position = {282, 0}, corner_size = 8},
    shadow = textbox_dirt
  },
  active_background = 
  {
    base = {position = {282, 0}, corner_size = 8},
    shadow = textbox_dirt
  },
  selection_background_color= {141, 90, 100},
  rich_text_setting = "enabled",
  rich_text_highlight_error_color = {166, 10, 10},
  rich_text_highlight_warning_color = {255, 90, 0},
  rich_text_highlight_ok_color = {63, 105, 0},
  selected_rich_text_highlight_error_color = {166, 10, 10},
  selected_rich_text_highlight_warning_color = {182, 62, 4},
  selected_rich_text_highlight_ok_color = {50, 80, 0}
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