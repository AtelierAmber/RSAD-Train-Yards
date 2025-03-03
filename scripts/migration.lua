local flib_migration = require("__flib__.migration")

---@type MigrationsTable
local version_migrations = {
  ["0.0.2"] = function()
    rsad_controller:__init()
    rsad_controller:__load()
  end
}

flib_migration.handle_on_configuration_changed(version_migrations)