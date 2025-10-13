local procedure_builder = require("scripts.gui.definitions.modules.procedure-node")
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]

local procedures_class = {}

---Adds a node to the graph gui
---@param self LuaGuiElement
---@param player_state RSAD.Gui.PlayerState
---@param action RSAD.Procedure.Action
function procedures_class.add_gui_node(self, player_state, action)
  local node_graph = rsad.gui.controller_refs[rsad.gui.procedures_tab.ref_names.procedure_nodes]
  local node = procedure_builder.build_node(action.name, builder.checkbox(nil, true))
  glib.add(node_graph, node)
end

---Constructs the node graph from the active procedure
---@param self LuaGuiElement
---@param player_state RSAD.Gui.PlayerState
function procedures_class.construct_node_graph(self, player_state)
  if not player_state.active_procedure then return end
  local procedure = rsad.procedures[player_state.active_procedure] --[[@as RSAD.Procedure]]
  if not procedure then return end

  local node_graph = rsad.gui.controller_refs[rsad.gui.procedures_tab.ref_names.procedure_nodes]
  node_graph.clear()
  for i, action in ipairs(procedure.action_steps) do
    self:add_gui_node(player_state, action)
    if i ~= #procedure.action_steps then
      glib.add(node_graph, procedure_builder.arrow)
    end
  end
end

return procedures_class