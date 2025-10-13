GLIB_CONFIG = {
  register_events = false,
  use_event_handler = false
} --[[@as Glib.Config]]
glib = require("__glib__.glib") --[[@as Glib]]
wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]

rsad.gui = {}
rsad.gui.ref_names = {
  main = "rsad-controller",
  mod_button = "rsad-controller-gui.mod-gui-button"
}

---@class RSAD.Gui.PlayerState
---@field index uint32
---@field active_yard string?
---@field active_procedure string?
---@field active_routine string?
---@field open_dialog string?

rsad.gui.states = {} --[[@type table<uint, RSAD.Gui.PlayerState>]]

local builder = require("scripts.gui.lib.gui-builder")

local controller_gui = require("scripts.gui.definitions.controller.controller-gui")
local train_view = require("scripts.gui.definitions.modules.train-view")

---@param event EventData.on_gui_click
local function click_mod_button(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local frame, refs
  if player.gui.screen[controller_gui.args.name] then
    frame = player.gui.screen[controller_gui.args.name]
  else
    frame, refs = glib.add(player.gui.screen, controller_gui)
    rsad.gui.controller_refs = refs

    --Trains
    local testf, testr = glib.add(refs["rsad_overview_train_views"], train_view)
    local testf, testr = glib.add(refs["rsad_overview_train_views"], train_view)
  end
  if frame then
    frame.focus()
    player.opened = frame.elem
  end
  if frame.construct then frame:construct(event, refs) end
end

local mod_button = builder.button(rsad.gui.ref_names.mod_button, click_mod_button, nil, { "rsad-controller-gui.mod-gui-button" })
wrapper.new_mod_gui(mod_button)

--glib.register_handlers(mod_button.handlers, nil, rsad.gui.ref_names.mod_button)
--glib.register_handlers(controller_gui.handlers, nil, rsad.gui.ref_names.main)

local function setup_gui_refs(self)
  rsad.gui.states = storage.gui_states
end

local gui_game_events = {}
gui_game_events.events = {} --[[@type table<defines.events, fun()>]]

function gui_game_events.on_init()
  if not storage.gui_states then storage.gui_states = {} end

  setup_gui_refs()
end

function gui_game_events.on_configuration_changed()
  gui_game_events.on_init()
end

function gui_game_events.on_load()
  setup_gui_refs()
end

glib.register_handlers(g_builder_handlers, nil, rsad.gui.ref_names.main)
local gui_handlers = {
  wrapper,
  glib,
  gui_game_events
}

return gui_handlers
