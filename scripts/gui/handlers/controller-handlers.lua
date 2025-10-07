local handlers = {}

---Closes the main window frame
---@param event GuiEventData
function handlers.close_controller(event)
  local main_frame = event.element.gui.screen[rsad.controller.gui.names.namespace] --[[@as LuaGuiElement]]
  if main_frame then
    main_frame.destroy()
  end
end

return handlers