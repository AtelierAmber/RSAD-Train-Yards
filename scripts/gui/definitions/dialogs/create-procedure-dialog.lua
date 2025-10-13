local wrapper = require("scripts.gui.lib.gui-wrapper") --[[@as RSAD.GuiWrapper]]
local builder = require("scripts.gui.lib.gui-builder") --[[@as RSAD.GuiBuilder]]

local handlers = require("scripts.gui.handlers.dialog-handlers")

rsad.gui.procedures_tab.create_dialog = {}
rsad.gui.procedures_tab.create_dialog.ref_names = {
  main = "create_procedure_dialog"
}

local ref_names = rsad.gui.procedures_tab.create_dialog.ref_names

local dialog = builder.frame(ref_names.main, nil, true, {minimal_height = 200, minimal_width = 300}, {tags = {is_dialog = true}})
:center()
:with_events({_closed = handlers.cancel_dialog}){
  builder.hflow(){ -- Title
    builder.label({"rsad-controller-gui.dialog.create-procedure"}, nil, "frame_title"),
    builder.dragger("title.drag", ref_names.main, {minimal_height = 24}),
    builder.button("title.close", handlers.cancel_dialog, "close_button", nil, nil, "utility/close", nil, {tags = {dialog_close_target = ref_names.main,}})
  },
  builder.frame("params_frame", nil, true, {horizontally_stretchable = true, vertically_stretchable = true}){
    builder.hflow("params_flow"){
      builder.label({"rsad-controller-gui.dialog.create-procedure-name-field"}),
      builder.spacer(false, true),
      builder.text_field("create_procedure_name", nil, nil, nil, nil, nil, true, true, "invalid_value_textfield", nil, {tooltip = {"rsad-controller-gui.dialog.invalid-name"}})
      :with_events({_text_changed = handlers.on_procedure_name_updated})
    }
  },
  builder.hflow(){
    builder.button("cancel-create-procedure", handlers.cancel_dialog, "red_back_button", {"rsad-controller-gui.dialog.cancel"}, {"", "TODO"}, nil, nil, {tags = {dialog_close_target = ref_names.main,}}),
    builder.spacer(false, true),
    builder.button("confirm-create-procedure", handlers.confirm_create_procedure_dialog, "confirm_button", {"rsad-controller-gui.dialog.create-procedure"}, {"", "TODO"}, nil, nil, {tags = {dialog_close_target = ref_names.main,}})
  }
}

return dialog