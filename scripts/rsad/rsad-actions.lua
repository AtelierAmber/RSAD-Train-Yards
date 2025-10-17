local max_cargo_limit = settings.startup["rsad-station-max-cargo-limit"].value --[[@as integer]]

---@enum RSAD.Procedure.BuiltInAction
BuiltInAction = {
  move = "move",
  couple = "couple",
  decouple = "decouple",
  decouple_all_cargo = "decouple_all_cargo"
}

---@enum RSAD.Procedure.RuntimeParamType
RuntimeParamType = {
  train = {
    locomotive_count = "train.locomotive_count",
    carriage_count = "train.carriage_count",
    wagon_count = "train.wagon_count",
    arrival_front_dir = "train.arrival_front_dir", --Defined as the train_end that stopped closest to the station
    arrival_rear_dir = "train.arrival_rear_dir", --Defined as opposite to arrival_front

    -- Train Type Seeking
    front_carriage = "train.front_carriage", -- Based on arrival direction
    rear_carriage = "train.rear_carriage", -- Based on arrival direction
    front_locomotive = "train.front_locomotive", -- Based on arrival direction
    rear_locomotive = "train.rear_locomotive", -- Based on arrival direction
  },
  logistic = {
    requested_carriages = "logistic.requested_carriages",
  }
}

---@enum RSAD.Procedure.TrainType
TrainType = {
  locomotive = "locomotive", -- Train Engines/Locomotives
  carriage = "carriage", -- All types of train stocks
  wagon = "wagon" -- Fluid or Cargo train stocks
}

---@enum RSAD.Procedure.MoveType
MoveType = {
  move_by_wagon = {name = "move_by_wagon", step = 1, min = 1, max = max_cargo_limit}, -- Distance will be in # of wagons
  move_by_segment = {name = "move_by_segment", step = 1, min = 1, max = 100}, -- Distance will be in number of signals (1 is stop at first signal, 2 is second)
  move_by_distance = {name = "move_by_distance", min = 0, max = 200}, -- Distance will be in tiles/whatever the train uses for speed units
}

---@type table<RSAD.Procedure.BuiltInAction, RSAD.Procedure.Action>
rsad.builtin_actions = {}
rsad.builtin_actions[BuiltInAction.move] = {
  internal_type = BuiltInAction.move,
  call = "move_train",
  params = {
    move_type = MoveType.move_by_wagon.name,
    distance = 1,
    direction = {runtime = true, variable = RuntimeParamType.train.arrival_rear_dir}
  }
}
rsad.builtin_actions[BuiltInAction.couple] = {
  internal_type = BuiltInAction.couple,
  call = "couple_to",
  params = {
    direction = {runtime = true, variable = RuntimeParamType.train.arrival_front_dir}
  }
}
rsad.builtin_actions[BuiltInAction.decouple] = {
  internal_type = BuiltInAction.decouple,
  call = "decouple_from",
  params = {
    track_from = {runtime = true, variable = RuntimeParamType.train.rear_locomotive},
    offset = 0,
    direction = {runtime = true, variable = RuntimeParamType.train.arrival_front_dir}
  }
}
rsad.builtin_actions[BuiltInAction.decouple_all_cargo] = {
  internal_type = BuiltInAction.decouple_all_cargo,
  call = "decouple_all_cargo",
  params = {
    track_from = {runtime = true, variable = RuntimeParamType.train.rear_locomotive},
    offset = 0,
    direction = {runtime = true, variable = RuntimeParamType.train.arrival_front_dir}
  }
}

---@class RSAD.Procedure.Action
---@field public internal_type RSAD.Procedure.BuiltInAction
---@field public custom_name string?
---@field public call string
---@field public params table<string, nil|string|number|boolean|table|RSAD.Procedure.RuntimeParam>

---@class RSAD.Procedure.RuntimeParam
---@field public runtime boolean
---@field public variable RSAD.Procedure.RuntimeParamType|string