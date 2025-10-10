---@alias RSAD.GuiBuilder.Constructor fun(self:LuaGuiElement, ...)

---@class RSAD.GuiBuilder : GuiElemDef
---@field handlers? GuiEventHandler[]
---@field center? fun(self:RSAD.GuiBuilder):RSAD.GuiBuilder
---@field with_construction? fun(self:RSAD.GuiBuilder, name:string, constructor:RSAD.GuiBuilder.Constructor):RSAD.GuiBuilder
local builder = {}
local builder_meta = {
  ---Use {} from a return function of builder to initialize children
  ---@param self RSAD.GuiBuilder
  ---@return RSAD.GuiBuilder
  __call = function(self, ...)
    self.children = self.children or {}
    self.handlers = self.handlers or {}
    if not self.tab then
      for _, child in pairs(...) do
        assert(type(child) == "table" and (child.args or child.tab), "Failed to create gui. Child, \"" ..
          serpent.line(child) .. "\" is not of type table. It is " .. tostring(type(child)))
        if child.tab then assert(self.args.type == "tabbed-pane", "Parent of tabs must be a tabbed-pane!") end
        table.insert(self.children, child)
        child.parent = self
        if child.handlers then
          for hname, handler in pairs(child.handlers) do
            local found = false
            for exname, existing in pairs(self.handlers) do
              if existing == handler then
                found = true
              end
              if exname == hname then
                error("Failed to make handler " .. hname .. " since it already exists in this element!")
              end
            end
            if not found then
              self.handlers[hname] = handler
            else
              self.handlers[hname] = function(evnt) handler(evnt) end
            end
          end
          child.handlers = nil
        end
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
      if child.handlers then
        for hname, handler in pairs(child.handlers) do
          local found = false
          for exname, existing in pairs(self.handlers) do
            if existing == handler then
              found = true
            end
            if exname == hname then
              error("Failed to make handler " .. hname .. " since it already exists in this element!")
            end
          end
          if not found then
            self.handlers[hname] = handler
          else
            self.handlers[hname] = function(evnt) handler(evnt) end
          end
        end
        child.handlers = nil
      end
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
  ---@type RSAD.GuiBuilder
  local frame = {
    --[[@type LuaGuiElement.add_param.frame]]
    args = {
      type = "frame",
      name = name,
      style = style,
      direction = ((vertical ~= nil) and ((vertical and "vertical") or "horizontal")) or nil,
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
  ---@type RSAD.GuiBuilder
  local spacer = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "empty-widget",
      name = name,
      style = style,
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
  ---@type RSAD.GuiBuilder
  local spacer = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "empty-widget",
      name = name,
      style = "draggable_space",
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
  ---@type RSAD.GuiBuilder
  local label = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "label",
      name = name,
      style = style or "label",
      caption = caption,
    },
    style_mods = stylemods,
    elem_mods = emods,
  }
  local self = builder.make(label)
  return self
end

---Creates a button
---@param name string
---@param handler GuiEventHandler
---@param style string?
---@param caption LocalisedString?
---@param tooltip LocalisedString?
---@param sprite string?
---@param stylemods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.button(name, handler, style, caption, tooltip, sprite, stylemods, emods)
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
      sprite = sprite
    },
    style_mods = stylemods,
    elem_mods = emods,
    _click = handler
  }
  button.handlers = {}
  button.handlers[(name .. "._click")] = handler
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
---@return RSAD.GuiBuilder
function builder.tabbed_pane(name, style, stylemods)
  ---@type RSAD.GuiBuilder
  local pane = {
    --[[@type LuaGuiElement.add_param]]
    args = {
      type = "tabbed-pane",
      name = name,
      style = style,
    },
    style_mods = stylemods
  }
  local self = builder.make(pane)
  return self
end

---Creates a tab within the parent frame. Must have only a single child which is the content frame
---@param name string
---@param label LocalisedString?
---@return RSAD.GuiBuilder
function builder.pane_tab(name, label)
  local tab = {
    ---@type RSAD.GuiBuilder
    tab = {
      --[[@type LuaGuiElement.add_param.tab]]
      args = {
        type = "tab",
        name = name,
        caption = label
      }
    }
  }
  local self = builder.make(tab)
  return self
end

---Creates a listbox 
---@param name string?
---@param items LocalisedString[]?
---@param selected uint32?
---@param style string?
---@param stylemods StyleMods?
---@return RSAD.GuiBuilder
function builder.list(name, items, selected, style, stylemods)
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
    style_mods = stylemods
  }
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

---Returns current context window
---@param namespace string
---@param min_size integer|integer[]?
---@return RSAD.GuiBuilder
function builder.make_window(namespace, min_size)
  ---@type RSAD.GuiBuilder
  local window = {
    _closed = builder.default_handlers.window_close,
    --[[@type LuaGuiElement.add_param.frame]]
    args = {
      type = "frame",
      name = namespace,
      caption = { "", namespace },
      style = "frame"
    },
    style_mods = {
      minimal_width = (min_size and min_size[1]) or 1,
      minimal_height = (min_size and min_size[2]) or 1,
      vertically_stretchable = true,
      horizontally_stretchable = true,
    }
  }
  window.handlers = {}
  window.handlers[(namespace .. "._closed")] = builder.default_handlers.window_close
  local self = builder.make(window)
  return self --[[@as RSAD.GuiBuilder]]
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
---@param constructor RSAD.GuiBuilder.Constructor
---@return RSAD.GuiBuilder
function builder:with_construction(name, constructor)
  if self.class then
    error("Trying to register GUIBuilder class to a gui twice!")
    return self
  end

  glib.register_class(name, {construct = function (elem)
    constructor(elem)
  end})
  --self.class = name

  return self
end

---Adds fields to an element builder
---@param events table<string, GuiEventHandler>
function builder:with_events(events)
  local self_name = (self.args and self.args.name) or (self.tab and self.tab.args and self.tab.args.name)
  self.handlers = self.handlers or {}
  for key, value in pairs(events) do
    self[key] = value
    self.handlers[(self_name .. "." .. key)] = value
  end
  return self
end

---@class RSAD.GuiBuilderMeta.Index
---@field center fun(self:RSAD.GuiBuilder)
---@field with_construction fun(self:RSAD.GuiBuilder, name:string, constructor:fun(self:LuaGuiElement, ...))
builder_meta.__index = {
  center = builder.center,
  with_construction = builder.with_construction,
  with_events = builder.with_events,
}
--

--MARK: Default Handlers
builder.default_handlers = {}

function builder.default_handlers.window_close(event)
  event.element.destroy()
end

---

return builder --[[@as RSAD.GuiBuilder]]
