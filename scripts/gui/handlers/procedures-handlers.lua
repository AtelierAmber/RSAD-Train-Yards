local builder = require("scripts.gui.lib.gui-builder")
local node_handlers = require("scripts.gui.handlers.procedure-node-handlers")
local create_procedure_dialog = require("scripts.gui.definitions.dialogs.create-procedure-dialog")
local core_util = require("util")

local handlers = {}

---comment
---@param event GuiEventData
function handlers.open_create_procedure(event)
  --TODO Fix crash when procedure dialog is already open
  local player = game.get_player(event.player_index)
  if not player then error("No player found when opening create procedure dialog!") end

  local player_state = rsad.gui.states[event.player_index]
  local elem, refs = glib.add(event.element.gui.screen, create_procedure_dialog)

  if player_state then
    player_state.open_dialog = elem.name
  end

  player.opened = elem
  refs["create_procedure_name"].focus()
end

---Add node to currently active procedure
---@param event EventData.on_gui_click
function handlers.add_node(event)
  --- Backend
  local player_state = rsad.gui.states[event.player_index]
  local active_procedure = player_state.active_procedure
  if not active_procedure then return end
  local steps = rsad.procedures[active_procedure].action_steps
  if not steps then steps = {} end
  table.insert(steps, core_util.table.deepcopy(rsad.builtin_actions[BuiltInAction.move]))

  --- Gui stuff
  local procedures_tab = rsad.gui.controller_refs[rsad.gui.procedures_tab.ref_names.main]
  if procedures_tab.construct_node_graph then 
    local added_nodes = procedures_tab:construct_node_graph(player_state)
    if #added_nodes > 0 then
      --local new_node = 
    end
  end
end

---Set active procedure when selected from list
---@param event EventData.on_gui_selection_state_changed
function handlers.set_active_procedure(event)
  local new_index = event.element.selected_index
  local new_item = event.element.items[new_index]
  if new_item then
    local player_state = rsad.gui.states[event.player_index]
    player_state.active_procedure = new_item --[[@as string]]

    local procedures_tab = rsad.gui.controller_refs[rsad.gui.procedures_tab.ref_names.main]
    if procedures_tab.construct_node_graph then procedures_tab:construct_node_graph(player_state) end
  end
end

return handlers