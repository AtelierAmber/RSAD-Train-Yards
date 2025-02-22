local rsad_station = flib.copy_prototype(data.raw["arithmetic-combinator"]["arithmetic-combinator"], names.entities.rsad_station)

rsad_station.icon = "__rsad-train-yards__/graphics/icons/rsad-station.png"
rsad_station.corpse = "small-remnants"
rsad_station.placeable_by = {item = names.entities.rsad_station, count = 1} -- so that player can pipette items
rsad_station.localised_name = {"entity-name." .. names.entities.rsad_station}
rsad_station.minable = {
    mining_time = 0.1,
    result = names.entities.rsad_station
  }
rsad_station.energy_source = {
    type = "void"
}
rsad_station.active_energy_usage = "1kW"
rsad_station.flags = {
    "get-by-unit-number",
    "placeable-neutral",
    "player-creation"
}

rsad_station.sprites = {}
for _, dir in pairs({ "north", "east", "south", "west" }) do
    rsad_station.sprites[dir] = {layers = {}}
    rsad_station.sprites[dir].layers[1] = {
        filename = "__rsad-train-yards__/graphics/entities/rsad-station.png",
        width = 64,
        height = 64,
        scale = 0.5,
    }
end

rsad_station.type = "arithmetic-combinator"

data.extend({
    rsad_station
})