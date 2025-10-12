local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]

local handlers = require("scripts.gui.handlers.dialog-handlers")

local dialog = builder.frame("rsad-controller-gui.dialog.create-yard", nil, true, {minimal_height = 200, minimal_width = 300}, {tags = {is_dialog = true}})
:center()
:with_events({_closed = handlers.cancel_dialog}){
  builder.hflow(){ -- Title
    builder.label({"rsad-controller-gui.dialog.create-yard"}, nil, "frame_title"),
    builder.dragger("title.drag", "rsad-controller-gui.dialog.create-yard", {minimal_height = 24}),
    builder.button("title.close", handlers.cancel_dialog, "close_button", nil, nil, "utility/close", nil, {tags = {dialog_close_target = "rsad-controller-gui.dialog.create-yard",}})
  },
  builder.frame("params_frame", nil, true, {horizontally_stretchable = true, vertically_stretchable = true}){
    builder.hflow("params_flow"){
      builder.label({"rsad-controller-gui.dialog.create-yard-name-field"}),
      builder.spacer(false, true),
      builder.text_field("create_yard_name", nil, nil, nil, nil, nil, true, true, "invalid_value_textfield", nil, {tooltip = {"rsad-controller-gui.dialog.invalid-name"}})
      :with_events({_text_changed = handlers.on_name_updated})
    }
  },
  builder.hflow(){
    builder.button("cancel-create-yard", handlers.cancel_dialog, "red_back_button", {"rsad-controller-gui.dialog.cancel"}, {"", "TODO"}, nil, nil, {tags = {dialog_close_target = "rsad-controller-gui.dialog.create-yard",}}),
    builder.spacer(false, true),
    builder.button("confirm-create-yard", handlers.confirm_create_yard_dialog, "confirm_button", {"rsad-controller-gui.dialog.create-yard"}, {"", "TODO"}, nil, nil, {tags = {dialog_close_target = "rsad-controller-gui.dialog.create-yard",}})
  }
}

return dialog