local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]
local handlers = require("scripts.gui.handlers.procedure-node-handlers")

local next_node_arrow = builder.frame(nil, "invisible_frame", nil, 
{margin = 8, top_padding = 1, right_padding = -5, bottom_padding = 1, left_padding = 2, size = {0,0}, natural_height = 0, natural_width = 0}){
  builder.sprite("orange-right-arrow")
}

local procedure_builder = {arrow = next_node_arrow}

---Builds a procedure node with content
---@param name string?
---@param content RSAD.GuiBuilder[]|GuiElemDef[]
---@param update_func fun(action:RSAD.Procedure.Action, refs:table<string, LuaGuiElement>)
---@return RSAD.GuiBuilder
local function build_node(name, class_name, content, update_func)
  local procedure_node = builder.frame(nil, "invisible_frame", nil, {horizontally_stretchable = false, vertically_stretchable = false, use_header_filler = false, padding = 0}){
    builder.frame("node_frame", "train_schedule_partially_fullfilled_condition_frame", true, {size = {260, 260}, padding = 3}){
      builder.vflow(nil, nil, {vertical_spacing = 0}){
        builder.frame(nil, "deep_frame_in_shallow_frame_for_description", false, {horizontally_stretchable = true}){
          --builder.label(name, "node_name", "subheader_caption_label"),
          builder.text_box("node_name", name),
          builder.spacer(false, true),
          builder.button("delete_node_button", handlers.delete_node, "tool_button_red", nil, nil, "utility.trash")
        },
        builder.vscroll(nil, "always", "scroll_pane_in_shallow_frame", {padding = 0}){
          builder.frame("content", "blueprint_parameter_frame", true, {margin = -4, horizontally_stretchable = true, vertically_stretchable = true})
          :with_class(class_name, {update = update_func})
          (content){
            builder.spacer(true, true, nil, "entity_frame_filler", {margin = -8})
          }
        }
      }
    }
  }

  return procedure_node
end

--- Action GUIs

--- Need to register the interface events seperately from builder
local param_type_guis = {
  ["number"] = function(name, localised, value)  end,
  ["string"] = function(name, localised, value) builder.hflow(name){builder.label(localised, name .. "label"), builder.spacer(false, true, name .. "spacer"), builder.text_field(name .. "interface", value)} end,
  ["boolean"] = nil,
  ["table"] = nil,
  ["function"] = nil,
  ["thread"] = nil,
  ["userdata"] = nil,
}

---Helper to build a gui for a param
---@param name string
---@param interface function
local function make_param(name, interface, prename_args, postname_args, prename_args_count)
  local built = builder.hflow(name){
    builder.label({"rsad-actions.params." .. name}, name .. ".label"), 
    builder.spacer(false, true, name .. ".spacer")
  }
  if prename_args then
    if postname_args then
      table.insert(built, interface(table.unpack(prename_args, 1, prename_args_count or #prename_args), "move_type" .. ".interface", table.unpack(postname_args, #postname_args)))
    else
      table.insert(built, interface(table.unpack(prename_args, prename_args_count or #prename_args), "move_type" .. ".interface"))
    end
  elseif postname_args then
    table.insert(built, interface("move_type" .. ".interface"), table.unpack(postname_args))
  else
    table.insert(built, interface("move_type" .. ".interface"))
  end
  
  return built
end

---@type table<RSAD.Procedure.BuiltInAction, RSAD.GuiBuilder|GuiElemDef[]>
local builtin_action_param_guis = {
  [BuiltInAction.move] = {
    make_param("move_type", builder.dropdown),
    make_param("distance", builder.slider),
    make_param("direction", builder.dropdown),
  }
}

---@type table<RSAD.Procedure.BuiltInAction, fun(action:RSAD.Procedure.Action, refs:table<string, LuaGuiElement>)>
local builtin_action_updators = {
  [BuiltInAction.move] = function(action, refs)
    local move_type_gui = refs["move_type"]
    local distance_gui = refs["distance"]
    local direction_gui = refs["direction"]
    if not move_type_gui or not distance_gui or not direction_gui then error("Failed to construct move node!") end

    --- Move Type
    local movetype_interface = move_type_gui["move_type.interface"]
    local movetypeitems = {}
    local movetype_index = -1
    for _, t in pairs(MoveType) do
      table.insert(movetypeitems, {"rsad-actions." .. t})
      if t == action.params.move_type then
        movetype_index = #movetypeitems
      end
    end
    movetype_interface.items = movetypeitems
    movetype_interface.selected_index = movetype_index

    --- Distance
    local distance_label = distance_gui["distance.label"]
    local distance_interface = distance_gui["distance.interface"]
    distance_label.caption = {action.params.move_type .. "_distance"}
    distance_interface.set_slider_value_step(MoveType[action.params.move_type].step)
    if MoveType[action.params.move_type].min then distance_interface.set_slider_minimum_maximum(MoveType[action.params.move_type].min, MoveType[action.params.move_type].max) end

    --- Direction
    local direction_interface = direction_gui["direction.interface"]
    local direction_items = {
      {"rsad-actions." .. RuntimeParamType.train.arrival_front_dir},
      {"rsad-actions." .. RuntimeParamType.train.arrival_rear_dir},
    }
    local direction_index = -1
    for i, t in pairs(direction_items) do
      if t == action.params.direction.variable then
        direction_index = i
      end
    end
    direction_interface.items = direction_items
    direction_interface.selected_index = direction_index
  end
}

--- Builds a node from an action
---@param action RSAD.Procedure.Action
function procedure_builder.build_action_node(action)
  return build_node(action.custom_name, action.internal_type, builtin_action_param_guis[action.internal_type], builtin_action_updators[action.internal_type])
end

return procedure_builder