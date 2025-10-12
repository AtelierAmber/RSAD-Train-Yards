local handlers = require("scripts.gui.handlers.controller-handlers")
local builder = require("scripts.gui.lib.gui-builder")
local core_util = require("util")

local ref_names = rsad.gui.ref_names

---@type RSAD.Gui.PlayerState
local default_gui_state = {
  active_yard = nil,
  open_dialog = nil
}

rsad.gui.controller_size = {1616, 820}

---@param self LuaGuiElement
---@param event EventData.on_gui_click
---@param refs table<string, LuaGuiElement> refs The table of element references, indexed by element name.
local function rsad_gui_construct(self, event, refs)
  if not event then
    error("Cannot construct RSAD gui outside of player contexted event!")
  end
  local player = game.get_player(event.player_index)
  if not player then
    error("Trying to construct RSAD gui without player!")
  end
  
  local state = rsad.gui.states[event.player_index]
  if not state then 
    rsad.gui.states[event.player_index] = core_util.table.deepcopy(default_gui_state)
    state = rsad.gui.states[event.player_index]
  end
  rsad.gui.controller_refs = refs
  
  if self.update then self:update(state) end
end

---Updates currently shown information on controller gui
---@param self LuaGuiElement
---@param player_state RSAD.Gui.PlayerState
local function rsad_gui_update(self, player_state)
  if rsad.yards and rsad.gui.controller_refs then
    local overview_yard_list = rsad.gui.controller_refs[rsad.gui.overview_tab.ref_names.yard_list]
    local logistics_yard_list = rsad.gui.controller_refs[rsad.gui.logistics_tab.ref_names.yard_list]
    if overview_yard_list or logistics_yard_list then
      --- Find named yard or 0
      local selected_yard_i = 0
      local i = 0
      local yard_names = {}
      for _, yard in pairs(rsad.yards) do
        i = i+1
        if yard.name == player_state.active_yard then
          selected_yard_i = i
        end
        yard_names[i] = yard.name
      end
      if overview_yard_list then
        overview_yard_list.items = yard_names
        overview_yard_list.selected_index = selected_yard_i
        for _, item in pairs(overview_yard_list.children) do
          glib.add(item, builder.button("delete_item_button", handlers.delete_item, "tool_button_red", nil, nil, "utility.trash"))
        end
      end
      if logistics_yard_list then
        logistics_yard_list.items = yard_names
        logistics_yard_list.selected_index = selected_yard_i
      end
    end
  end
end

--Main Frame
---@type RSAD.GuiBuilder
local main_frame = 
builder.frame(ref_names.main, "frame", true, {size = rsad.gui.controller_size})
  :center()
  :with_class(ref_names.main, {construct = rsad_gui_construct, update = rsad_gui_update})
  :with_events({_closed = handlers.close_controller}) {
  builder.hflow(){
    builder.label({"rsad-controller-gui.frame-title"}, nil, "frame_title"),
    builder.dragger("title.drag", ref_names.main, {minimal_height = 24}),
    builder.button("title.close", handlers.close_controller, "close_button", nil, nil, "utility/close")
  },
  builder.frame("tab_frame", "inside_deep_frame"){
    builder.tabbed_pane("main_tabs", "rsad_tabbed_pane_expanded_content"){
      builder.pane_tab("overview_tab", {"rsad-controller-gui.overview-tab-title"}){
        require("scripts.gui.definitions.controller.overview-gui")
      },
      builder.pane_tab("logistics_tab", {"rsad-controller-gui.logistics-tab-title"}){
        require("scripts.gui.definitions.controller.logistics-gui")
      },
      builder.pane_tab("routine_tab", {"rsad-controller-gui.routine-tab-title"}){
        require("scripts.gui.definitions.controller.routines-gui")
      },
      builder.pane_tab("procedure_tab", {"rsad-controller-gui.procedure-tab-title"}){
        require("scripts.gui.definitions.controller.procedures-gui")
      },
    },
  }
}

return main_frame
