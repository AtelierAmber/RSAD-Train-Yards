local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]
local handlers = require("scripts.gui.handlers.procedure-node-handlers")

local next_node_arrow = builder.frame(nil, "invisible_frame", nil, 
{margin = 8, top_padding = 1, right_padding = -5, bottom_padding = 1, left_padding = 2, size = {0,0}, natural_height = 0, natural_width = 0}){
  builder.sprite("orange-right-arrow")
}

local procedure_builder = {arrow = next_node_arrow}


function procedure_builder.build_node(name, ...)
  local procedure_node = builder.frame(nil, "invisible_frame", nil, {horizontally_stretchable = false, vertically_stretchable = false, use_header_filler = false, padding = 0}){
    builder.frame("node_frame", "train_schedule_partially_fullfilled_condition_frame", true, {size = {260, 260}, padding = 3}){
      builder.vflow(nil, nil, {vertical_spacing = 0}){
        builder.frame(nil, "deep_frame_in_shallow_frame_for_description", false, {horizontally_stretchable = true}){
          builder.label({"", name}, "node_name", "subheader_caption_label"),
          builder.spacer(false, true),
          builder.button("delete_node_button", handlers.delete_node, "tool_button_red", nil, nil, "utility.trash")
        },
        builder.vscroll(nil, "always", "scroll_pane_in_shallow_frame", {padding = 0}){
          builder.frame(nil, "blueprint_parameter_frame", true, {margin = -4, horizontally_stretchable = true, vertically_stretchable = true})({...}){
            builder.spacer(true, true, nil, "entity_frame_filler", {margin = -8})
          }
        }
      }
    }
  }

  return procedure_node
end

return procedure_builder