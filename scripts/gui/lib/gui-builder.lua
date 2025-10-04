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
          serpent.line(child) .. "\" is not of type table.")
        if child.tab then assert(self.args.type == "tabbed-pane", "Parent of tabs must be a tabbed-pane!") end
        table.insert(self.children, child)
        child.parent = self
        if child.handlers then
          for _, handler in pairs(child.handlers) do
            table.insert(self.handlers, handler)
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
        for _, handler in pairs(child.handlers) do
          table.insert(self.handlers, handler)
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
function builder.frame(name, style, vertical, stylemods)
  ---@type RSAD.GuiBuilder
  local frame = {
    --[[@type LuaGuiElement.add_param.frame]]
    args = {
      type = "frame",
      name = name,
      style = style,
      direction = ((vertical ~= nil) and ((vertical and "vertical") or "horizontal")) or nil,
    },
    style_mods = mods,
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
---@param mods StyleMods
---@return RSAD.GuiBuilder
function builder.table(column_count, name, style, draw_vertical_lines, draw_horizontal_lines, mods)
  ---@type RSAD.GuiBuilder
  local frame = {
    --[[@type LuaGuiElement.add_param.table]]
    args = {
      type = "table",
      name = name,
      style = style,
      draw_vertical_lines = draw_vertical_lines,
      draw_horizontal_lines = draw_horizontal_lines,
    },
    style_mods = mods,
  }
  local self = builder.make(frame)
  return self
end

---Standard Horizontal Flow Definition
---@param name string?
---@param style string?
---@param mods StyleMods?
---@return RSAD.GuiBuilder
function builder.hflow(name, style, mods)
  ---@type RSAD.GuiBuilder
  local flow = {
    --[[@type LuaGuiElement.add_param.flow]]
    args = {
      type = "flow",
      name = name,
      style = style,
      direction = "horizontal",
    },
    style_mods = mods,
  }
  local self = builder.make(flow)
  return self
end

---Standard Horizontal Flow Definition
---@param name string?
---@param style string?
---@param mods StyleMods?
---@return RSAD.GuiBuilder
function builder.vflow(name, style, mods)
  ---@type RSAD.GuiBuilder
  local flow = {
    --[[@type LuaGuiElement.add_param.flow]]
    args = {
      type = "flow",
      name = name,
      style = style,
      direction = "vertical",
    },
    style_mods = mods,
  }
  local self = builder.make(flow)
  return self
end

---Size filling spacer
---@param v boolean? Is vertically stretchable. Defaults to false
---@param h boolean? Is horizontally stretchable. Defaults to true
---@param name string?
---@param style string?
---@param mods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.spacer(v, h, name, style, mods, emods)
  ---@type RSAD.GuiBuilder
  local spacer = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "empty-widget",
      name = name,
      style = style,
    },
    style_mods = mods or {},
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
---@param mods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.dragger(name, target, mods, emods)
  ---@type RSAD.GuiBuilder
  local spacer = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "empty-widget",
      name = name,
      style = "draggable_space",
    },
    style_mods = mods or {},
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
---@param mods StyleMods?
---@param emods ElemMods?
---@return RSAD.GuiBuilder
function builder.label(caption, name, style, mods, emods)
  ---@type RSAD.GuiBuilder
  local label = {
    --[[@type LuaGuiElement.add_param.base]]
    args = {
      type = "label",
      name = name,
      style = style or "label",
      caption = caption,
    },
    style_mods = mods,
    elem_mods = emods,
  }
  local self = builder.make(label)
  return self
end

---Creates a button
---@param name string
---@param handler GuiEventHandler
---@param caption LocalisedString?
---@return RSAD.GuiBuilder
function builder.button(name, handler, caption)
  ---@type RSAD.GuiBuilder
  local button = {
    --[[@type LuaGuiElement.add_param.button]]
    args = {
      type = "button",
      name = name,
      mouse_button_filter = { "left" },
      caption = caption,
    },
    _click = handler
  }
  button.handlers = {}
  button.handlers[(name .. "._click")] = handler
  local self = builder.make(button)
  return self
end

---Creates a tab within the parent frame. Must have only a single child which is the content frame
---@param name string?
---@param style string?
---@return RSAD.GuiBuilder
function builder.tabbed_pane(name, style)
  ---@type RSAD.GuiBuilder
  local pane = {
    --[[@type LuaGuiElement.add_param]]
    args = {
      type = "tabbed-pane",
      style = style or nil,
    }
  }
  local self = builder.make(pane)
  return self
end

---Creates a tab within the parent frame. Must have only a single child which is the content frame
---@param name string
---@return RSAD.GuiBuilder
function builder.tab(name)
  local tab = {
    ---@type RSAD.GuiBuilder
    tab = {
      --[[@type LuaGuiElement.add_param.tab]]
      args = {
        type = "tab",
        name = name,
        caption = {"", "test"}
      }
    }
  }
  local self = builder.make(tab)
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
  window.handlers = { builder.default_handlers.window_close }
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

---@class RSAD.GuiBuilderMeta.Index
---@field center fun(self:RSAD.GuiBuilder)
---@field with_construction fun(self:RSAD.GuiBuilder, name:string, constructor:fun(self:LuaGuiElement, ...))
builder_meta.__index = {
  center = builder.center,
  with_construction = builder.with_construction,
}
--

--MARK: Default Handlers
builder.default_handlers = {}

function builder.default_handlers.window_close(event)
  event.element.destroy()
end

---

return builder --[[@as RSAD.GuiBuilder]]
