local gui = require("__gui-modules__.gui")
local rsad = require("scripts.rsad")
local flib_queue = require("__flib__.queue") ---@type flib_queue

---@alias (partial) modules.GuiElemDef
---| flib.GuiElemDef

---@class RSAD.Gui
---@field public definition modules.GuiElemDef
---@field private stack flib.Queue<flib.GuiElemDef|table>
rsad.gui = {
    stack = flib_queue.new()
}

---Pushes the last element to the stack and adds following elements to its children
---@param self RSAD.Gui
---@return self
function rsad.gui.with(self)
    assert(self, "Cannot construct gui object. \"with\" called when self was nil")
    local active = self.stack[self.stack.first]
    flib_queue.push_front(self.stack, active.children[#active.children])
    return self
end

---Pops last element from the stack and adds following elements as its siblings
---@param self RSAD.Gui
---@return self
function rsad.gui.next(self)
    assert(self, "Cannot construct gui object. \"next\" called when self was nil")
    flib_queue.pop_front(self.stack)

    return self
end

---Simple frame container
---@param self RSAD.Gui
---@param name string?
---@param style string?
---@param vertical boolean If true, sets the frame to vertical, otherwise horizontal
function rsad.gui.frame(self, name, style, vertical)
    ---@type flib.GuiElemDef
    local frame = {
        type = "frame",
        name = name,
        style = style,
        direction = (vertical and "vertical") or "horizontal",
        style_mods = mods,
    }
    self = rsad.gui.add(self, frame)
    return self
end

---Constructs a grid container (factorio type "table")
---@param self RSAD.Gui
---@param column_count number
---@param name string?
---@param style string?
---@param draw_vertical_lines boolean?
---@param draw_horizontal_lines boolean?
---@param mods StyleMods
function rsad.gui.table(self, column_count, name, style, draw_vertical_lines, draw_horizontal_lines, mods)
    ---@type flib.GuiElemDef
    local frame = {
        type = "table",
        name = name,
        style = style,
        draw_vertical_lines = draw_vertical_lines,
        draw_horizontal_lines = draw_horizontal_lines,
        style_mods = mods,
    }
    self = rsad.gui.add(self, frame)
    return self
end

---Standard Horizontal Flow Definition
---@param self RSAD.Gui?
---@param name string?
---@param style string?
---@param mods StyleMods
---@return self
function rsad.gui.hflow(self, name, style, mods)
    ---@type flib.GuiElemDef
    local flow = {
        type = "flow",
        name = name,
        style = style,
        direction = "horizontal",
        style_mods = mods,
    }
    self = rsad.gui.add(self, flow)
    return self
end

---Standard Horizontal Flow Definition
---@param self RSAD.Gui?
---@param name string?
---@param style string?
---@param mods StyleMods
---@return self
function rsad.gui.vflow(self, name, style, mods)
    ---@type flib.GuiElemDef
    local flow = {
        type = "flow",
        name = name,
        style = style,
        direction = "vertical",
        style_mods = mods,
    }
    self = rsad.gui.add(self, flow)
    return self
end

---Size filling spacer
---@param self RSAD.Gui?
---@param v boolean? Is vertically stretchable. Defaults to false
---@param h boolean? Is horizontally stretchable. Defaults to true
---@return RSAD.Gui
function rsad.gui.spacer(self, v, h)
    ---@type flib.GuiElemDef
    local spacer = {
        type = "empty-widget",
        style_mods = {horizontally_stretchable = (h ~= nil and h) or true, vertically_stretchable = v} --[[@type StyleMods]] 
    }
    self = rsad.gui.add(self, spacer)
    return self
end

---Standard Horizontal Flow Definition
---@param self RSAD.Gui?
---@param caption LocalisedString
---@param name string?
---@param style string?
---@param mods StyleMods
---@return self
function rsad.gui.label(self, caption, name, style, mods)
    ---@type flib.GuiElemDef
    local label = {
        type = "label",
        name = name,
        style = style or "label",
        caption = caption,
        style_mods = mods,
    }
    self = rsad.gui.add(self, label)
    return self
end

---Allows for a custom GUI element definition to be added
---@param self RSAD.Gui?
---@param definition modules.GuiElemDef
---@return self
function rsad.gui.custom(self, definition)
    self = rsad.gui.add(self, definition)
    return self
end

---@package
---@param self RSAD.Gui?
---@param definition modules.GuiElemDef
---@return self
function rsad.gui.add(self, definition)
    if not self then self = table.deepcopy(rsad.gui) end
    if self.definition then
        local active = self.stack[self.stack.first]
        table.insert(active.children, definition)
    else
        self.definition = definition
    end
    return self
end
---Returns current context as a GuiModules.GuiWindowDef
---@param self RSAD.Gui
---@param namespace string
---@param version number?
---@return GuiWindowDef
function rsad.gui.as_root_window(self, namespace, version)
    return {
        namespace = namespace,
        root = "screen",
        version = version or 1,
        custominput = namespace,
        shortcut = namespace,
        definition = self.definition
    }
end

---Test
rsad.gui.hflow():with()
    :hflow()
    :hflow():with()
        :hflow()
        :next()
    :hflow()
    :next()
:hflow():as_root_window("")