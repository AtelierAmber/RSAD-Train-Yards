local procedure_builder = require("scripts.gui.definitions.modules.procedure-node")
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]

local procedures_class = {}

---Constructs the node graph from the active procedure
---@param self LuaGuiElement
---@param player_state RSAD.Gui.PlayerState
---@return LuaGuiElement[]? -- Array of all nodes added
function procedures_class.construct_node_graph(self, player_state)
  if not player_state.active_procedure then return nil end
  local procedure = rsad.procedures[player_state.active_procedure] --[[@as RSAD.Procedure]]
  if not procedure then return nil end

  local added_nodes = {}
  local node_graph = rsad.gui.controller_refs[rsad.gui.procedures_tab.ref_names.procedure_nodes]
  node_graph.clear()
  for i, action in ipairs(procedure.action_steps) do
    local new_node = procedure_builder.build_action_node(action)
    local added, refs = glib.add(node_graph, new_node)
    if added then
      table.insert(added_nodes, added)
      if refs["content"].update then refs["content"].update(action, refs) end
      if i ~= #procedure.action_steps then
        glib.add(node_graph, procedure_builder.arrow)
      end
    end
  end

  return added_nodes
end

return procedures_class