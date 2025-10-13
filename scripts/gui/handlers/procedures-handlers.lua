local builder = require("scripts.gui.lib.gui-builder")
local procedure_builder = require("scripts.gui.definitions.modules.procedure-node")
local node_handlers = require("scripts.gui.handlers.procedure-node-handlers")
local create_procedure_dialog = require("scripts.gui.definitions.dialogs.create-procedure-dialog")

local handlers = {}

---comment
---@param event GuiEventData
function handlers.open_create_procedure(event)
  local player = game.get_player(event.player_index)
  if not player then error("No player found when opening create procedure dialog!") end

  local player_state = rsad.gui.states[event.player_index]
  local elem, refs = glib.add(event.element.gui.screen, create_procedure_dialog)

  if player_state then
    player_state.open_dialog = elem.name
  end

  player.opened = elem
end

---Add node to currently active procedure
---@param event EventData.on_gui_click
function handlers.add_node(event)
  local nodes = rsad.gui.controller_refs["procedure_nodes"]
  local node = procedure_builder.build_node("test1", builder.label("Test"), builder.checkbox("check", true))
  local arr_elem, arr_ref = glib.add(nodes, procedure_builder.arrow)
  local node_elem, node_ref = glib.add(nodes, node)
end

return handlers