---@class (exact) __RSAD_STORAGE
---@field public needs_tick boolean Enabled when rsad needs every tick monitored (scripted trains and such)
---@field public scripted_trains table<uint, ScriptedTrainDestination>
---@field public stations table<uint, RSAD.Station>
---@field public train_yards table<string, RSAD.TrainYard>
storage = {}

require("prototypes.names")
rsad_controller = require("scripts.rsad.rsad-controller")
rsad_controller:register_events()

require("scripts.migration")

require("scripts.gui.events")
require("scripts.gui.station-gui")

require("scripts.util.events")
events.init()