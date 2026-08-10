local operators = {
    add = function(a, b)
        return a + b
    end,
    sub = function(a, b)
        return a - b
    end,
    mul = function(a, b)
        return a * b
    end,
    div = function(a, b)
        return a / b
    end,
}

---@alias Operator fun(base: Color, value: Color): Color

---@class Operation
---@field operator Operator Apply the operation to the color
---@field value Color
local Operation = {}
Operation.__index = Operation

---Create a new operation
---@param operator Operator
---@param value Color
function Operation.new(operator, value)
    local obj = {
        operator = operator,
        value = value,
    }

    return setmetatable(obj, Operation)
end

--- Apply the operation to the given color
---@param value Color
function Operation:apply_to(value)
    return self.operator(value, self.value)
end

---@class Palette
---@field [string] Color
---@field _colors {[string]: Color} The unaltered colors in the palette
---@field _operations {[string]: Color} The operations to be applied to colors in the palette
local Palette = {}

--- Create a new instance of the class
---@param colors {[string]: Color}|nil
---@return Palette
function Palette.new(colors)
    colors = colors or {}

    local obj = {
        _colors = colors,
        _operations = {},
    }

    setmetatable(obj, Palette)

    return obj
end

---Clone the palette
---@return Palette
function Palette:clone()
    local copy = self.new()
    local colors = rawget(copy, "_colors")
    local operations = rawget(copy, "_operations")

    for k, v in pairs(rawget(self, "_colors")) do
        colors[k] = v:clone()
    end
    for i, v in ipairs(rawget(self, "_operations")) do
        table.insert(operations, i, v)
    end

    return copy
end

---Get an original, unaltered color from the palette
---@param key string
---@return Color?
function Palette:get_original(key)
    return rawget(self, "_colors")[key]
end

---Remove all operations from the palette
function Palette:reset()
    self._operations = {}

    return self
end

---Alter the palette by applying an operation
---@param operator Operator
---@param value Color
---@return Palette
function Palette:alter(operator, value)
    local new = self:clone()

    table.insert(new._operations, Operation.new(operator, value))

    return new
end

function Palette:__add(a, b)
    return a:alter(operators.add, b)
end

function Palette:__sub(a, b)
    return a:alter(operators.sub, b)
end

function Palette:__mul(a, b)
    return a:alter(operators.mul, b)
end

function Palette:__div(a, b)
    return a:alter(operators.div, b)
end

function Palette:__pow(a, b)
    return a:alter(math.pow, b)
end

function Palette:__mod(a, b)
    return a:alter(math.fmod, b)
end

function Palette:__index(key)
    local own = rawget(self, "_colors")[key]
    if own == nil then
        return rawget(Palette, key)
    end

    local modified = own
    for _, operation in ipairs(rawget(self, "_operations")) do
        modified = operation:apply_to(modified)
    end

    return modified
end

function Palette:__newindex(key, value)
    rawget(self, "_colors")[key] = value
end

return Palette
