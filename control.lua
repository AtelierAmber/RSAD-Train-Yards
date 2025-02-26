require("prototypes.names")
rsad_controller = require("scripts.rsad.rsad-controller")
rsad_controller:register_events()

require("scripts.gui.events")
require("scripts.gui.station-gui")

require("scripts.util.events")
events.init()