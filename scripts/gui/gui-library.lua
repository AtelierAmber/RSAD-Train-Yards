local gui = require("__gui-modules__.gui")
local flib_queue = require("__flib__.queue") ---@type flib_queue

---@alias (partial) modules.GuiElemDef
---| flib.GuiElemDef

---@class GuiBuilder : flib.GuiElemDef
local builder = {}
local builder_meta = {
    __index = builder,
    __call = function (self, ...)
        self.children = {}
        for _, child in pairs(arg) do
            assert(type(child) == "table", "Failed to create gui. Child, \"".. serpent.line(child) .."\" is not of type table.")
            table.insert(self.children, child)
        end
        return self
    end
}

---Simple frame container
---@param name string?
---@param style string?
---@param vertical boolean? If true, sets the frame to vertical, otherwise horizontal
function builder.frame(name, style, vertical)
    ---@type flib.GuiElemDef
    local frame = {
        type = "frame",
        name = name,
        style = style,
        direction = (vertical and "vertical") or "horizontal",
        style_mods = mods,
    }
    self = builder.make(frame)
    return self
end

---Constructs a grid container (factorio type "table")
---@param column_count number
---@param name string?
---@param style string?
---@param draw_vertical_lines boolean?
---@param draw_horizontal_lines boolean?
---@param mods StyleMods
function builder.table(column_count, name, style, draw_vertical_lines, draw_horizontal_lines, mods)
    ---@type flib.GuiElemDef
    local frame = {
        type = "table",
        name = name,
        style = style,
        draw_vertical_lines = draw_vertical_lines,
        draw_horizontal_lines = draw_horizontal_lines,
        style_mods = mods,
    }
    self = builder.make(frame)
    return self
end

---Standard Horizontal Flow Definition
---@param name string?
---@param style string?
---@param mods StyleMods
---@return self
function builder.hflow(name, style, mods)
    ---@type flib.GuiElemDef
    local flow = {
        type = "flow",
        name = name,
        style = style,
        direction = "horizontal",
        style_mods = mods,
    }
    self = builder.make(flow)
    return self
end

---Standard Horizontal Flow Definition
---@param name string?
---@param style string?
---@param mods StyleMods
---@return self
function builder.vflow(name, style, mods)
    ---@type flib.GuiElemDef
    local flow = {
        type = "flow",
        name = name,
        style = style,
        direction = "vertical",
        style_mods = mods,
    }
    self = builder.make(flow)
    return self
end

---Size filling spacer
---@param v boolean? Is vertically stretchable. Defaults to false
---@param h boolean? Is horizontally stretchable. Defaults to true
---@return GuiBuilder
function builder.spacer(v, h)
    ---@type flib.GuiElemDef
    local spacer = {
        type = "empty-widget",
        style_mods = {horizontally_stretchable = (h ~= nil and h) or true, vertically_stretchable = v} --[[@type StyleMods]] 
    }
    self = rsad.gui.add(spacer)
    return self
end

---Standard Horizontal Flow Definition
---@param caption LocalisedString
---@param name string?
---@param style string?
---@param mods StyleMods
---@return self
function builder.label(caption, name, style, mods)
    ---@type flib.GuiElemDef
    local label = {
        type = "label",
        name = name,
        style = style or "label",
        caption = caption,
        style_mods = mods,
    }
    self = builder.make(label)
    return self
end

---Allows for a custom GUI element definition to be added
---@param definition modules.GuiElemDef
---@return self
function builder.custom(definition)
    return builder.make(definition)
end
---@package
---@param definition modules.GuiElemDef
---@return GuiBuilder
function builder.make(definition)
    setmetatable(definition, builder_meta)
    return self
end
---Returns current context as a GuiModules.GuiWindowDef
---@param namespace string
---@param version number?
---@return GuiBuilder
function builder.make_root_window(namespace, version)
    local window = {
        namespace = namespace,
        root = "screen",
        version = version or 1,
        custominput = namespace,
        shortcut = namespace,
---@diagnostic disable-next-line: missing-fields
        definition = {
            type = "module", module_type = "window_frame",
            name = namespace, title = {namespace},
            has_close_button = true, has_pin_button = true
        }
    } --[[@as GuiWindowDef]]
    builder.make(window.definition)
    return window.definition --[[@as GuiBuilder]]
end

builder.make_root_window("namespace") {
    builder.hflow() {
        builder.label({ "label1" }),
        builder.spacer(),
        builder.label({ "label2" })
    },
    builder.hflow() {
        builder.vflow() {
            builder.label({ "label11" }),
            builder.label({ "label12" })
        },
        builder.spacer(),
        builder.vflow() {
            builder.label({ "label21" }),
            builder.label({ "label22" }),
        }
    }
}

return builder