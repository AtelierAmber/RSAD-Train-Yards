local mod_gui = require("mod-gui")

---@class RSAD.GuiWrapper
local wrapper = {
  overlay_buttons = {},
  overlay_frames = {},
}

---Adds a new window on screen
---@param definition GuiElemDef
function wrapper.new_mod_gui(definition)
  if definition.args.type == "button" then
    table.insert(wrapper.overlay_buttons, {
      name = definition.args.name,
      definition = definition
    })
  elseif definition.args.type == "flow" then
    table.insert(wrapper.overlay_frames, {
      name = definition.args.name,
      definition = definition
    })
  end
end

function wrapper.create_with_scope(player)
  for _, button in pairs(wrapper.overlay_buttons) do
    local mod_button = mod_gui.get_button_flow(player)
    if mod_button[button.name] then mod_button[button.name].destroy() end
    glib.add(mod_button, button.definition)
  end
  for _, frame in pairs(wrapper.overlay_frames) do
    local mod_frame = mod_gui.get_frame_flow(player)
    if mod_frame[frame.name] then mod_frame[frame.name].destroy() end
    glib.add(mod_frame, frame.definition)
  end
end

function wrapper.on_init()
  for i, player in pairs(game.players) do
    wrapper.create_with_scope(player)
  end
end

function wrapper.on_configuration_changed()
  wrapper.on_init()
end

wrapper.events = {

}

return wrapper
