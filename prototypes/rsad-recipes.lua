local rsad_station_recipe = flib.copy_prototype(data.raw["recipe"]["train-stop"], names.entities.rsad_station)

rsad_station_recipe.enabled = false
rsad_station_recipe.subgroup = data.raw["recipe"]["train-stop"].subgroup

local rail_transport_tech = data.raw["technology"]["automated-rail-transportation"]

rail_transport_tech.effects[#data.raw["technology"]["automated-rail-transportation"].effects+1] = {
    recipe = names.entities.rsad_station,
    type = "unlock-recipe"
}

data.raw["technology"]["automated-rail-transportation"] = rail_transport_tech

data.extend({rsad_station_recipe})