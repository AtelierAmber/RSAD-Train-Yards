---@alias RSAD.GuiBuilder.Constructor fun(self:LuaGuiElement, event:EventData, ...)

g_builder_func_names = g_builder_func_names or {} --[[@type table<fun(event: GuiEventData), string>]]
g_builder_handlers = g_builder_handlers or {} --[[@type table<string, fun(event: GuiEventData)>]]

---@class RSAD.GuiBuilder : GuiElemDef
---@field center? fun(self:RSAD.GuiBuilder):RSAD.GuiBuilder
---@field with_class? fun(self:RSAD.GuiBuilder, name:string, class_funcs:table<string, fun(...):any>):RSAD.GuiBuilder
local builder = {}
local builder_meta = {
  ---Use {} from a return function of builder to initialize children
  ---@param self RSAD.GuiBuilder
  ---@return RSAD.GuiBuilder
  __call = function(self, ...)
    self.children = self.children or {}
    if not self.tab then
      for _, child in pairs(...) do
        assert(type(child) == "table" and (child.args or child.tab), "Failed to create gui. Child, \"" ..
          serpent.line(child) .. "\" is not of type table. It is " .. tostring(type(child)))
        if child.tab then assert(self.args.type == "tabbed-pane", "Parent of tabs must be a tabbed-pane!") end
        table.insert(self.children, child)
        child.parent = self
      end
    else
      if #... > 1 then
        error("Trying to construct tab with multiple content frames!")
        return self
      end
      local child = select(1, ...)[1]
      assert(type(child) == "table" and (child.args or child.tab), "Failed to create gui. Child, \"" ..
        serpent.line(child) .. "\" is not of type table.")
      child.parent = self
      self.content = child
    end
    return self
  end
}

---Simple frame container
---@param name string?
---@param style string?
---@param vertical boolean? If true, sets the frame to vertical, otherwise horizontal
---@param stylemods StyleMods?
---@param emods ElemMods?
function builder.frame(name, style, vertical, stylemods, emods)
  local emod_tags = emods and emods.tags
  if emod_tags then emods.tags = nil end
  ---@type RSAD.GuiBuilder
  local frame = {
    --[[@type LuaGuiElement.add_param.frame]]
    args = {
      type = "frame",
      name = name,
      style = style,
      direction = ((vertical ~= nil) and ((vertical and "vertical") or "horizontal")) or nil,
      tags = emod_tags,
    },
    style_mods = stylemods,
    elem_mods = emods
  }
  local self = builder.make(frame)
  return self
end

---Constructs a grid container (factorio type "table")
---@param column_count number
---@param name string?
---@param style string?
---@param draw_vertical_lines boolean?
---@param draw_horizontal_lines boolean?
---@param stylemods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.table(column_count, name, style, draw_vertical_lines, draw_horizontal_lines, stylemods, emods)
  local emod_tags = emods and emods.tags
  if emod_tags then emods.tags = nil end
  ---@type RSAD.GuiBuilder
  local frame = {
    --[[@type LuaGuiElement.add_param.table]]
    args = {
      type = "table",
      name = name,
      style = style,
      column_count = column_count,
      draw_vertical_lines = draw_vertical_lines,
      draw_horizontal_lines = draw_horizontal_lines,
      tags = emod_tags,
    },
    style_mods = stylemods,
    elem_mods = emods
  }
  local self = builder.make(frame)
  return self
end

---Standard Horizontal Flow Definition
---@param name string?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.hflow(name, style, stylemods)
  ---@type RSAD.GuiBuilder
  local flow = {
    --[[@type LuaGuiElement.add_param.flow]]
    args = {
      type = "flow",
      name = name,
      style = style,
      direction = "horizontal",
    },
    style_mods = stylemods,
  }
  local self = builder.make(flow)
  return self
end

---Standard Horizontal Flow Definition
---@param name string?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.vflow(name, style, stylemods)
  ---@type RSAD.GuiBuilder
  local flow = {
    --[[@type LuaGuiElement.add_param.flow]]
    args = {
      type = "flow",
      name = name,
      style = style,
      direction = "vertical",
    },
    style_mods = stylemods,
  }
  local self = builder.make(flow)
  return self
end

---Standard scroll frame
---@param name string?
---@param vbehavior ScrollPolicy?
---@param hbehavior ScrollPolicy?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.scroll(name, vbehavior, hbehavior, style, stylemods)
  ---@type RSAD.GuiBuilder
  local flow = {
    --[[@type LuaGuiElement.add_param.scroll_pane]]
    args = {
      type = "scroll-pane",
      name = name,
      style = style,
      horizontal_scroll_policy = hbehavior or "auto-and-reserve-space",
      vertical_scroll_policy = vbehavior or "auto-and-reserve-space"
    },
    style_mods = stylemods,
  }
  local self = builder.make(flow)
  return self
end

---Standard Horizontal scroll frame
---@param name string?
---@param behavior ScrollPolicy?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.vscroll(name, behavior, style, stylemods)
  ---@type RSAD.GuiBuilder
  local flow = {
    --[[@type LuaGuiElement.add_param.scroll_pane]]
    args = {
      type = "scroll-pane",
      name = name,
      style = style,
      horizontal_scroll_policy = "never",
      vertical_scroll_policy = behavior or "auto-and-reserve-space"
    },
    style_mods = stylemods,
  }
  local self = builder.make(flow)
  return self
end

---Standard Horizontal scroll frame
---@param name string?
---@param behavior ScrollPolicy?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.hscroll(name, behavior, style, stylemods)
  ---@type RSAD.GuiBuilder
  local pane = {
    --[[@type LuaGuiElement.add_param.scroll_pane]]
    args = {
      type = "scroll-pane",
      name = name,
      style = style,
      horizontal_scroll_policy = behavior or "auto-and-reserve-space",
      vertical_scroll_policy = "never",
      
    },
    style_mods = stylemods,
  }
  local self = builder.make(pane)
  return self
end

---Size filling spacer
---@param v boolean? Is vertically stretchable. Defaults to false
---@param h boolean? Is horizontally stretchable. Defaults to true
---@param name string?
---@param style string?
---@param stylemods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.spacer(v, h, name, style, stylemods, emods)
  local emod_tags = emods and emods.tags
  if emod_tags then emods.tags = nil end
  ---@type RSAD.GuiBuilder
  local spacer = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "empty-widget",
      name = name,
      style = style,
      tags = emod_tags
    },
    style_mods = stylemods or {},
    elem_mods = emods
  }
  spacer.style_mods.horizontally_stretchable = (h ~= nil and h)
  spacer.style_mods.vertically_stretchable = v
  local self = builder.make(spacer)
  return self
end

---Draggable
---@param name string?
---@param target string?
---@param stylemods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.dragger(name, target, stylemods, emods)
  local emod_tags = emods and emods.tags
  if emod_tags then emods.tags = nil end
  ---@type RSAD.GuiBuilder
  local spacer = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "empty-widget",
      name = name,
      style = "draggable_space",
      tags = emod_tags,
    },
    style_mods = stylemods or {},
    elem_mods = emods,
    drag_target = target,
  }
  spacer.style_mods.horizontally_stretchable = true
  local self = builder.make(spacer)
  return self
end

---Standard Horizontal Flow Definition
---@param caption LocalisedString
---@param name string?
---@param style string?
---@param stylemods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.label(caption, name, style, stylemods, emods)
  local emod_tags = emods and emods.tags
  if emod_tags then emods.tags = nil end
  ---@type RSAD.GuiBuilder
  local label = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "label",
      name = name,
      style = style or "label",
      caption = caption,
      tags = emod_tags,
    },
    style_mods = stylemods,
    elem_mods = emods,
  }
  local self = builder.make(label)
  return self
end

---Creates a button
---@param name string
---@param click fun(event: GuiEventData)
---@param style string?
---@param caption LocalisedString?
---@param tooltip LocalisedString?
---@param sprite string?
---@param stylemods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.button(name, click, style, caption, tooltip, sprite, stylemods, emods)
  local emod_tags = emods and emods.tags
  if emod_tags then emods.tags = nil end
  ---@type RSAD.GuiBuilder
  local button = {
    --[[@type LuaGuiElement.add_param.button]]
    args = {
      type = sprite and "sprite-button" or "button",
      name = name,
      mouse_button_filter = { "left" },
      caption = caption,
      tooltip = tooltip,
      style = style,
      sprite = sprite,
      tags = emod_tags
    },
    style_mods = stylemods,
    elem_mods = emods,
    _click = click
  }
  
  if click then
    local ename = g_builder_func_names[click]
    if not ename then
      ename = (name or "button") .. ".handler._click"
      if g_builder_handlers[ename] then
        error("Duplicate name for handler!")
      end
      g_builder_func_names[click] = ename
      g_builder_handlers[ename] = click
    end
  end
  local self = builder.make(button)
  return self
end

---Creates a checkbox
---@param name string?
---@param state boolean?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.checkbox(name, state, style, stylemods)
  ---@type RSAD.GuiBuilder
  local pane = {
    --[[@type LuaGuiElement.add_param.checkbox]]
    args = {
      type = "checkbox",
      name = name,
      style = style,
      state = state or false
    },
    style_mods = stylemods
  }
  local self = builder.make(pane)
  return self
end

---Creates a tabbed pane for use with tabs.
---@param name string?
---@param style string?
---@param stylemods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.tabbed_pane(name, style, stylemods, emods)
  ---@type RSAD.GuiBuilder
  local pane = {
    --[[@type LuaGuiElement.add_param]]
    args = {
      type = "tabbed-pane",
      name = name,
      style = style,
    },
    style_mods = stylemods,
    elem_mods = emods
  }
  local self = builder.make(pane)
  return self
end

---Creates a tab within the parent frame. Must have only a single child which is the content frame
---@param name string
---@param label LocalisedString?
---@return RSAD.GuiBuilder
---@param stylemods StyleMods?
function builder.pane_tab(name, label, stylemods, emods)
  local tab = {
    ---@type RSAD.GuiBuilder
    tab = {
      --[[@type LuaGuiElement.add_param.tab]]
      args = {
        type = "tab",
        name = name,
        caption = label
      }
    },
    style_mods = stylemods,
    elem_mods = emods
  }
  local self = builder.make(tab)
  return self
end

---Creates a listbox 
---@param name string
---@param stator fun(event: GuiEventData)
---@param items LocalisedString[]?
---@param selected uint32?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.list(name, stator, items, selected, style, stylemods)
  ---@type RSAD.GuiBuilder
  local def = {
    --[[@type LuaGuiElement.add_param.list_box]]
    args = {
      type = "list-box",
      name = name,
      style = style,
      items = items,
      selected_index = selected
    },
    style_mods = stylemods,
    _selection_state_changed = stator
  }

  if stator then
    local ename = g_builder_func_names[stator]
    if not ename then
      ename = (name or "list") .. ".handler._selection_state_changed"
      if g_builder_handlers[ename] then
        error("Duplicate name for handler!")
      end
      g_builder_func_names[stator] = ename
      g_builder_handlers[ename] = stator
    end
  end
  local self = builder.make(def)
  return self
end

---Creates a dropdown selector
---@param name string?
---@param items LocalisedString[]?
---@param selected uint32?
---@param style string?
---@return RSAD.GuiBuilder
function builder.dropdown(name, items, selected, style)
  ---@type RSAD.GuiBuilder
  local def = {
    --[[@type LuaGuiElement.add_param.drop_down]]
    args = {
      type = "drop-down",
      name = name,
      style = style,
      items = items,
      selected_index = selected
    }
  }
  local self = builder.make(def)
  return self
end

---Creates a minimap view
---@param name string?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.minimap(name, style, stylemods)
  ---@type RSAD.GuiBuilder
  local def = {
    --[[@type LuaGuiElement.add_param.minimap]]
    args = {
      type = "minimap",
      name = name,
      style = style,
    },
    style_mods = stylemods
  }
  local self = builder.make(def)
  return self
end

---Creates a sprite
---@param path SpritePath
---@param name string?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.sprite(path, name, style, stylemods)
  ---@type RSAD.GuiBuilder
  local def = {
    --[[@type LuaGuiElement.add_param.sprite]]
    args = {
      type = "sprite",
      name = name,
      style = style,
      sprite = path
    },
    style_mods = stylemods
  }
  local self = builder.make(def)
  return self
end

---Creates a text field
---@param name string?
---@param initial string?
---@param numeric boolean?
---@param decimal boolean?
---@param negative boolean?
---@param password boolean?
---@param lose_focus boolean?
---@param icon boolean?
---@param style string?
---@param stylemods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.text_field(name, initial, numeric, decimal, negative, password, lose_focus, icon, style, stylemods, emods)
  ---@type RSAD.GuiBuilder
  local def = {
    --[[@type LuaGuiElement.add_param.textfield]]
    args = {
      type = "textfield",
      name = name,
      style = style,
      text = initial,
      numeric = numeric,
      allow_decimal = decimal,
      allow_negative = negative,
      is_password = password,
      lose_focus_on_confirm = lose_focus,
      icon_selector = icon,
    },
    style_mods = stylemods
  }
  local self = builder.make(def)
  return self
end

---Allows for a custom GUI element definition to be added
---@param definition GuiElemDef
---@return RSAD.GuiBuilder
function builder.custom(definition)
  return builder.make(definition)
end

---@package
---@param definition GuiElemDef
---@return RSAD.GuiBuilder
function builder.make(definition)
  setmetatable(definition, builder_meta)
  return definition --[[@as RSAD.GuiBuilder]]
end

--MARK: Modifiers
--- ElemMod accessors

---

---Centers the element with auto_center
---@param self RSAD.GuiBuilder
---@return RSAD.GuiBuilder
function builder:center()
  self.elem_mods = self.elem_mods or {}
  self.elem_mods.auto_center = true
  return self
end

---Registers a constructor that can be called after add
---@param self RSAD.GuiBuilder
---@param name string
---@param class_funcs table<string, fun(...):any>
---@return RSAD.GuiBuilder
function builder:with_class(name, class_funcs)
  if self.class then
    error("Trying to register GUIBuilder class to a gui twice!")
    return self
  end

  glib.register_class(name, class_funcs)
  self.class = name

  return self
end

---Adds fields to an element builder
---@param events table<string, fun(event: GuiEventData)>
function builder:with_events(events)
  local self_name = (self.args and self.args.name) or (self.tab and self.tab.args and self.tab.args.name)
  for key, value in pairs(events) do
    self[key] = value
    local ename = g_builder_func_names[value]
    if not ename then
      ename = self_name .. ".handler." .. key 
      if g_builder_handlers[ename] then
        error("Duplicate name for handler!")
      end
      g_builder_func_names[value] = ename
      g_builder_handlers[ename] = value
    end
  end
  return self
end

---@class RSAD.GuiBuilderMeta.Index
---@field center fun(self:RSAD.GuiBuilder)
---@field with_construction fun(self:RSAD.GuiBuilder, name:string, constructor:fun(self:LuaGuiElement, ...))
builder_meta.__index = {
  center = builder.center,
  with_class = builder.with_class,
  with_events = builder.with_events,
}
--

return builder --[[@as RSAD.GuiBuilder]]
