local builder = require("scripts.gui.lib.gui-builder")
local procedure_builder = require("scripts.gui.definitions.modules.procedure-node")
local node_handlers = require("scripts.gui.handlers.procedure-node-handlers")
local create_procedure_dialog = require("scripts.gui.definitions.dialogs.create-procedure-dialog")

glib.register_handlers(procedure_builder.arrow.handlers, nil, "rsad_procedure_arrows")
glib.register_handlers(node_handlers, nil, "rsad_procedure_node")
glib.register_handlers(create_procedure_dialog.handlers, nil, "rsad_procedure_create_dialog")

local handlers = {}

---comment
---@param event GuiEventData
function handlers.open_create_procedure(event)
  local player = game.get_player(event.player_index)
  if not player then error("No player found when opening create procedure dialog!") end

  local player_state = rsad.gui.states[event.player_index]
  local elem, refs = glib.add(event.element.gui.screen, create_yard_dialog)

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