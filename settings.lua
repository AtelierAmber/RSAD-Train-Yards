data:extend{
  {
    type = "int-setting",
    name = "rsad-station-update-rate",
    setting_type = "startup",
    default_value = 60,
    order = "a"
  },
  {
    type = "int-setting",
    name = "rsad-station-max-train-limit",
    setting_type = "startup",
    minimum_value = 1,
    maximum_value = 16,
    default_value = 8,
    order = "b"
  },
  {
    type = "int-setting",
    name = "rsad-station-max-cargo-limit",
    setting_type = "startup",
    minimum_value = 1,
    maximum_value = 255,
    default_value = 8,
    order = "c"
  },
  --gui-modules registration
  require("scripts.gui.modules"),
}