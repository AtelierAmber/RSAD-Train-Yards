local rsad_station_item = flib.copy_prototype(data.raw["item"]["train-stop"], names.entities.rsad_station)

--rsad_station_item.icon = "__rsad-train-yards__/graphics/icons/rsad-station.png"
--rsad_station_item.icon_size = 64
rsad_station_item.subgroup = data.raw["item"]["train-stop"].subgroup
rsad_station_item.order = data.raw["item"]["train-stop"].order .. "-b"
rsad_station_item.place_result = names.entities.rsad_station

data.extend({
    rsad_station_item
})