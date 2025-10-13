---@class (exact) __RSAD_STORAGE
---@field public needs_tick boolean Enabled when rsad needs every tick monitored (scripted trains and such)
---@field public scripted_trains table<uint, ScriptedTrainDestination>
---@field public stops table<uint, RSAD.Station>
---@field public yards table<string, RSAD.TrainYard>
---@field public procedures table<string, RSAD.Procedure>
---@field public gui_states table<uint, RSAD.Gui.PlayerState>
storage = {}

require("definitions")

local handler = require("__core__.lualib.event_handler")

-- Core
handler.add_libraries({require("scripts.rsad.rsad")})

-- GUI
handler.add_libraries(require("scripts.gui.rsad-gui"))

-- require("prototypes.names")
-- rsad_controller = require("scripts.rsad.rsad-controller")
-- rsad_controller:register_events()

-- require("scripts.migration")

-- require("scripts.gui.events")
-- require("scripts.gui.station-gui")

-- require("scripts.util.events")
-- events.init()