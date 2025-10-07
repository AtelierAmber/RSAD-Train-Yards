GLIB_CONFIG = {
  register_events = false,
  use_event_handler = false
} --[[@as Glib.Config]]
glib = require("__glib__.glib") --[[@as Glib]]
wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]

local builder = require("scripts.gui.lib.gui-builder")

local controller_gui = require("scripts.gui.definitions.controller-gui")
local train_view = require("scripts.gui.definitions.modules.train-view")
local procedure_builder = require("scripts.gui.definitions.modules.procedure-node")
local node_handlers = require("scripts.gui.handlers.procedure-node-handlers")

---@param event EventData.on_gui_click
local function click_mod_button(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local frame, refs
  if player.gui.screen[controller_gui.args.name] then
    frame = player.gui.screen[controller_gui.args.name]
  else
    frame, refs = glib.add(player.gui.screen, controller_gui)
    --Trains
    local testf, testr = glib.add(refs["train_views"], train_view)
    local testf, testr = glib.add(refs["train_views"], train_view)

    --Procedures
    local node = procedure_builder.build_node("test1")
    local testf, testr = glib.add(refs["procedure_nodes"], node)
    local testf, testr = glib.add(refs["procedure_nodes"], procedure_builder.arrow)
  end
  if frame then
    frame.focus()
    player.opened = frame
  end
  --if frame.construct then frame:construct() end
end

local mod_button = builder.button(rsad.controller.gui.names.mod_button, click_mod_button, nil, { rsad.controller.gui.names.mod_button })
wrapper.new_mod_gui(mod_button)

glib.register_handlers(mod_button.handlers, nil, rsad.controller.gui.names.mod_button)
glib.register_handlers(controller_gui.handlers, nil, rsad.controller.gui.names.namespace)
glib.register_handlers(train_view.handlers, nil, "rsad_train_view")
glib.register_handlers(procedure_builder.arrow.handlers, nil, "rsad_procedure_arrows")
glib.register_handlers(node_handlers.handlers, nil, "rsad_procedure_node")

local gui_handlers = {
  wrapper,
  glib,
}

return gui_handlers
