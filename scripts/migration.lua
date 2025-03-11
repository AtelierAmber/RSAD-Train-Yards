local flib_migration = require("__flib__.migration")

---@type MigrationsTable
local version_migrations = {
  ["0.0.2"] = function()
    rsad_controller:__init()
    rsad_controller:__load()
  end,
  ["0.0.3"] = function()
    storage.needs_tick = false
  end,
  ["0.0.4"] = function()
    for _, station in pairs(storage.stations) do
      update_station_data(station, {train_limit = 1})
      station.assignments = 0
      ::continue::
    end
    rsad_controller:__load()
  end
}

flib_migration.handle_on_configuration_changed(version_migrations)