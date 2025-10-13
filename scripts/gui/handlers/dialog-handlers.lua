local handlers = {}

---@param elem LuaGuiElement
---@param new_name string
---@param check_table table<string, any>
local function on_name_updated(elem, new_name, check_table)
  if check_table[new_name] then
    elem.tooltip = {"rsad-controller-gui.dialog.invalid-name"}
    elem.style = "invalid_value_textfield"
  else
    elem.tooltip = nil
    elem.style = "textbox"
  end
end

---@param event EventData.on_gui_text_changed
function handlers.on_yard_name_updated(event)
  return on_name_updated(event.element, event.text, rsad.yards)
end
---@param event EventData.on_gui_text_changed
function handlers.on_procedure_name_updated(event)
  return on_name_updated(event.element, event.text, rsad.procedures)
end

---comment
---@param closer_elem LuaGuiElement
---@param player_index uint32
local function close_dialog(closer_elem, player_index)
  local target = closer_elem.tags and closer_elem.tags["dialog_close_target"] and closer_elem.gui.screen[closer_elem.tags["dialog_close_target"]]
  if not target then
    target = closer_elem --[[@as LuaGuiElement]]
  end
  local dialog_parent = target.tags["dialog_parent"]
  local target_name = target.name

  target.destroy()

  if dialog_parent then
    local player = game.get_player(player_index)
    local player_state = rsad.gui.states[player_index]
    if not player or not player_state then error("No player or player_state found when closing dialog!") end

    if player_state.open_dialog == target_name then
      player_state.open_dialog = nil
      player.opened = player.gui.screen[dialog_parent]
    end
  end
end

---@param event GuiEventData
function handlers.cancel_dialog(event)
  if not event.element then return end
  close_dialog(event.element, event.player_index)
end

---@param event EventData.on_gui_click
function handlers.confirm_create_yard_dialog(event)
  if not event.element then return end
  
  local params_flow = event.element.parent.parent.params_frame.params_flow
  local name = params_flow.create_yard_name.text
  if not name or name == "" then return end

  local new_yard = rsad:create_train_yard(name)
  
  if not new_yard then return end

  local player_state = rsad.gui.states[event.player_index]
  if not player_state then error("No player_state found for player " .. event.player_index .. "when confirming dialog!") end
  local main_frame = rsad.gui.controller_refs[rsad.gui.ref_names.main]
  if main_frame and main_frame.update then
    main_frame:update()
  end

  close_dialog(event.element, event.player_index)
end

---@param event EventData.on_gui_click
function handlers.confirm_create_procedure_dialog(event)
  if not event.element then return end
  
  local params_flow = event.element.parent.parent.params_frame.params_flow
  local name = params_flow.create_procedure_name.text
  if not name or name == "" then return end

  local new_procedure = rsad:create_procedure(name)
  
  if not new_procedure then return end

  local player_state = rsad.gui.states[event.player_index]
  if not player_state then error("No player_state found for player " .. event.player_index .. "when confirming dialog!") end
  local main_frame = rsad.gui.controller_refs[rsad.gui.ref_names.main]
  if main_frame and main_frame.update then
    main_frame:update()
  end

  close_dialog(event.element, event.player_index)
end

return handlers