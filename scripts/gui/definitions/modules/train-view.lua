local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]

local train_view = builder.frame(nil, "train_with_minimap_frame", nil, {horizontally_stretchable = false}){
  builder.vflow(){
    builder.button("train_map_button", function() game.print("map click") end, "locomotive_minimap_button", nil, nil, nil, {size = {260, 260}}){
      builder.minimap("train_map", nil)
    },
    builder.frame(nil, "deep_frame_in_shallow_frame", true){
      builder.button("train_status", function() end, "train_status_button", {"", "Test Train Status"})
    }
  }
}

return train_view