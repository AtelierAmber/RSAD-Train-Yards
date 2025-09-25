

---@class RSAD.GuiBuilder : GuiElemDef
local builder = {}
local builder_meta = {
    __call = function (self, ...)
        self.children = {}
        for _, child in pairs(...) do
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
---@param stylemods StyleMods?
function builder.frame(name, style, vertical, stylemods)
    ---@type GuiElemDef
    local frame = {
        args = {
            type = "frame",
            name = name,
            style = style,
            direction = (vertical and "vertical") or "horizontal",
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
    ---@type GuiElemDef
    local frame = {
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
    ---@type GuiElemDef
    local flow = {
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
    ---@type GuiElemDef
    local flow = {
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
---@return RSAD.GuiBuilder
function builder.spacer(v, h)
    ---@type GuiElemDef
    local spacer = {
        args = {
            type = "empty-widget",
        },
        style_mods = {horizontally_stretchable = (h ~= nil and h) or true, vertically_stretchable = v} --[[@type StyleMods]] 
    }
    local self = builder.make(spacer)
    return self
end

---Standard Horizontal Flow Definition
---@param caption LocalisedString
---@param name string?
---@param style string?
---@param mods StyleMods?
---@return RSAD.GuiBuilder
function builder.label(caption, name, style, mods)
    ---@type GuiElemDef
    local label = {
        args = {
            type = "label",
            name = name,
            style = style or "label",
            caption = caption,
        },
        style_mods = mods,
    }
    local self = builder.make(label)
    return self
end

---Creates a button
---@param name string
---@param handler string|table<string,string>
---@param caption LocalisedString?
---@return RSAD.GuiBuilder
function builder.button(name, handler, caption)
    ---@type GuiElemDef
    local button = {
        args = {
            type = "button",
            name = name,
            mouse_button_filter = {"left"},
            caption = caption,
        },
        handler = handler
    }
    local self = builder.make(button)
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

local window_meta = {
    __call = function (self, ...)
        self.definition.children = {}
        for _, child in pairs(...) do
            assert(type(child) == "table", "Failed to create gui. Child, \"".. serpent.line(child) .."\" is not of type table.")
            table.insert(self.definition.children, child)
        end
        return self
    end
}
---Returns current context window
---@param namespace string
---@param version number?
---@return RSAD.GuiBuilder
function builder.make_window(namespace, version)
    local window = {
        namespace = namespace,
        root = "screen",
        version = version or 1,
        custominput = namespace,
        --shortcut = namespace,
---@diagnostic disable-next-line: missing-fields
        definition = {
            type = "module", module_type = "window_frame",
            name = namespace, title = {namespace},
            has_close_button = true, has_pin_button = true
        }
    }
    setmetatable(window, window_meta)
    return window --[[@as RSAD.GuiBuilder]]
end

builder.make_window("namespace") {
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

return builder --[[@as RSAD.GuiBuilder]]