---@class RSAD
---@field public stops table<uint, RSAD.Station>
---@field public yards table<string, RSAD.TrainYard>
---@field public procedures table<string, RSAD.Procedure>
---@field public scheduler RSAD.Scheduler
rsad = {
  stops = nil, --[[@type table<uint, RSAD.Station>]]
  yards = nil, --[[@type table<string, RSAD.TrainYard>]]
  procedures = nil, --[[@type table<string, RSAD.Procedure>]]
  scheduler = scheduler, --[[@type RSAD.Scheduler]]
  shunter_networks = {}, --[[@type table<integer, string>]]           -- Train ID to TrainYard network hash
  station_assignments = {}, --[[@type table<integer, RSAD.Station>]]   -- Train ID to station it is parked at
  
  events = {}, --[[@type table<defines.events, fun(event:EventData)>]]
}

require("scripts.rsad.rsad-actions")

require("scripts.rsad.rsad-controller")

return rsad
