local utils = require("polychrome.utils")

---@overload fun(left: Color, right: number|Color): Color, number|Color Ensure the left argument is a color object.
---@overload fun(left: number|Color, right: Color): Color, number|Color Ensure the left argument is a color object.
local function ensure_left_arg_is_color(left, right)
    -- "color + number" and "color + color" syntax
    if type(left) ~= "number" then
        return left, right
    end

    assert(type(right) ~= "number", "Both arguments cannot be numbers.")

    -- "number + color" syntax
    return right, left
end

---@alias GamutType string
---@alias ColorValues number[]

---@alias ColorCache {[GamutType]: {[GamutType]: ColorValues?}?}

---Global cache for conversions between color gamuts.
---
---Gamut conversions are expensive, but given the same input value, they will
---always have the same result. That means that whenever a conversion is
---performed, we can cache the result and do a lookup for future conversions.
---@type ColorCache
local COLOR_CACHE = {}

---@alias AncestorCache {[GamutType]: {[GamutType]: Color?}?}

---Global cache for the parent hierarchy of gamuts.
---@type AncestorCache
local ANCESTOR_CACHE = {}

---@see Reference https://drafts.csswg.org/css-color/#color-conversion-code

---@class Color A generic color that can be converted to a hex value.
---@field __type string
---@field _is_color_object true
---@field components string[] The components of the gamut in the order they are specified.
---@overload fun(self: Color, ...: number): Color Create a new instance of the class.
---@operator unm(): Color Negate the color
---@operator add(number|Color): Color Add two colors
---@operator sub(number|Color): Color Subtract two colors
---@operator mul(number|Color): Color Multiply two colors
---@operator div(number|Color): Color Divide two colors
local Color = {
    _is_color_object = true,
}
Color.__index = Color

---Create a new instance of the class.
---@param first table|number
---@param ... number
---@return Color
function Color:new(first, ...)
    local rest = { ... }
    local obj = {}

    if type(first) == "table" and #first == 0 then
        -- `rgb({ r = 50, g = 100, b = 200 })` syntax
        for _, key in ipairs(self.components) do
            obj[key] = first[key]
        end
    else
        if type(first) == "table" then
            -- `rgb({ 50, 100, 200 })` syntax
            -- convert to `rgb(50, 100, 200)` syntax
            rest = first
        else
            -- `rgb(50, 100, 200)` syntax
            table.insert(rest, 1, first)
        end

        -- `rgb(50, 100, 200)` syntax
        for index, value in ipairs(rest) do
            local key = self.components[index]
            obj[key] = value
        end
    end

    setmetatable(obj, self)

    return obj
end

---Is the object a color object?
---@param obj any
---@return boolean
function Color.is_color(obj)
    return type(obj) == "table" and obj._is_color_object == true
end

function Color.from(self_or_value, value)
    local self = nil

    if Color.is_color(self_or_value) then
        self = self_or_value
    else
        value = self_or_value
    end

    local rgb = require("polychrome.color.rgb")
    local color
    if type(value) == "number" then
        -- raw number from vim hl
        color = rgb:from_number(value)
    elseif type(value) == "string" then
        -- hex string
        if vim.startswith(value, "#") then
            color = rgb:from_number(value)
        end
    end

    if self ~= nil then
        return color:to(self)
    end
end

---Convert the color to a `<number of components> x 1` matrix.
---@return Matrix
function Color:to_matrix()
    local matrix = require("polychrome.matrix")

    local rows = {}
    for _, key in ipairs(self.components) do
        table.insert(rows, self[key])
    end

    return matrix(rows)
end

---Get the parent color gamut
---@return Color?
function Color.get_parent_gamut()
    return nil
end

---Is the color the same type as the argument?
---@param _type Color|string
---@return boolean
function Color:is(_type)
    -- load class dynamically
    if type(_type) == "string" then
        local cls = require("polychrome.color")[_type]
        if not Color.is_color(cls) then
            error("No gamut found named '" .. _type .. "'.")
        end

        _type = cls
    end

    return self.__type == _type.__type
end

---Return the class of the color.
---@return Color?
function Color:get_type()
    local color = require("polychrome.color")
    for _, value in pairs(color) do
        if self:is(value) then
            return value
        end
    end

    return nil
end

---Return the parent chain of the gamut
---@return Color[]
function Color:parent_chain()
    local chain = {}
    ---@type Color?
    local parent = self:get_parent_gamut()

    while parent ~= nil do
        table.insert(chain, parent)
        parent = parent:get_parent_gamut()
    end

    return chain
end

---Return the descent chain of the gamut
---@return Color[]
function Color:_descent_chain()
    local chain = {}
    ---@type Color?
    local current = self

    while current and current:get_parent_gamut() ~= nil do
        table.insert(chain, current)
        current = current:get_parent_gamut()
    end

    return utils.reverse(chain)
end

---Get the common ancestor, if it exists.
---@param other Color
---@return Color?
function Color:get_common_ancestor(other)
    local self_cache = ANCESTOR_CACHE[self.__type]
    if self_cache ~= nil and self_cache[other.__type] ~= nil then
        return self_cache[other.__type]
    end

    -- no cache hit, let's actually find the ancestor
    local value = self:_get_common_ancestor(other)

    -- cache for both self and other
    if ANCESTOR_CACHE[self.__type] == nil then
        ANCESTOR_CACHE[self.__type] = {}
    end
    ANCESTOR_CACHE[self.__type][other.__type] = value

    if ANCESTOR_CACHE[other.__type] == nil then
        ANCESTOR_CACHE[other.__type] = {}
    end
    ANCESTOR_CACHE[other.__type][self.__type] = value

    return value
end

---Get the common ancestor, if it exists.
---@param other Color
---@return Color?
function Color:_get_common_ancestor(other)
    local up = self:parent_chain()
    table.insert(up, 1, self)
    local down = other:parent_chain()
    table.insert(down, 1, other)

    local longer, shorter
    if #up < #down then
        longer = down
        shorter = up
    else
        longer = up
        shorter = down
    end

    -- walk up the parent chain
    -- one could be an ancestor of the other, if so, shorter must be the ancestor
    for _, value in ipairs(shorter) do
        if utils.find(longer, value, self.is) then
            return value
        end
    end

    return nil
end

---Convert the color to another gamut
---@param _type Color|string
---@return Color?
function Color:to(_type)
    -- allow passing the name of the gamut as a string
    if type(_type) == "string" then
        local cls = require("polychrome.color")[_type]
        if not Color.is_color(cls) then
            error("No gamut found named '" .. _type .. "'.")
        end
        _type = cls
    end

    -- if we already have the right type, no-op
    if self:is(_type) then
        return self
    end

    -- perf: cache the hex conversion to avoid recalculating every time the color is used
    return self:_get_or_save_conversion_to_cache(_type, function()
        return self:_to(_type)
    end)
end

---Convert the color to another gamut, without caching logic
---@param _type Color
---@return Color?
function Color:_to(_type)
    local common = self:get_common_ancestor(_type)
    assert(common, "Gamuts do not have common ancestors.")

    -- convert up to the root
    local root = self:_up(common)
    -- convert down to the destination type
    return root:_down(_type)
end

---Convert the color to a gamut in the parent chain
---@param _type Color
---@return Color
function Color:_up(_type)
    local path = self:parent_chain()
    local goal = utils.find(path, _type, self.is)

    -- already the root
    if goal == nil then
        return self
    end

    local current = self
    for _ = 1, goal, 1 do
        local next = current:to_parent()
        assert(next, "Got nil when converting " .. current.__type .. " into parent")

        current = next
    end

    return current
end

---Convert the color to the parent type
---@return Color?
function Color:to_parent()
    return nil
end

---Convert the color to a gamut that has this type as an ancestor
---@param _type Color
---@return Color
function Color:_down(_type)
    -- going top-down, rather than bottom-up
    local path = _type:_descent_chain()

    -- find starting point, skip it if found
    local idx = utils.find(path, self, self.is)
    -- if not found, it must be the root, so just go from the start
    local start = idx ~= nil and idx + 1 or 1

    -- iterate backwards through the path
    local current = self
    for _, t in ipairs(utils.slice(path, start, #path)) do
        local next = t:from_parent(current)
        assert(next, "Got nil when converting " .. current.__type .. " into child")

        current = next
    end

    return current
end

---Convert the parent type to this type
---@param parent Color
---@return Color?
function Color:from_parent(parent)
    return nil
end

---Get a readable representation of the color
function Color:repr()
    local repr = self.__type .. "({ "

    repr = repr
        .. vim.iter(self.components)
            :map(function(c)
                return c .. " = " .. self[c]
            end)
            :join(", ")

    return repr .. " })"
end

---Perform an operation pairwise on each channel of the color
---@param other number|Color
---@param op Operator
---@return Color?
function Color:_per_channel_op(other, op)
    local destination_type = self:get_type()
    assert(destination_type, "Could not determine the type of the color.")

    -- "color + 128" syntax
    if type(other) == "number" then
        other = destination_type:new(other, other, other)
    end

    local other_type = other:get_type()
    assert(other_type, "Could not determine the type of the other color.")

    local converted = self:clone():to(other_type)
    assert(converted, "Could not convert " .. self.__type .. " to " .. other_type.__type)

    local components = {}
    for _, key in ipairs(converted.components) do
        table.insert(components, op(converted[key], other[key]))
    end

    return other_type:new(components):to(destination_type)
end

---Clone the color
---@return Color
function Color:clone()
    local values = {}
    for _, key in ipairs(self.components) do
        table.insert(values, self[key])
    end

    return self:get_type():new(values)
end

function Color:__call(...)
    return self:new(...)
end

function Color:__eq(other)
    for _, key in ipairs(self.components) do
        if self[key] ~= other[key] then
            return false
        end
    end

    return true
end

---Negate the color, returning a new color with each channel negated
---@return Color
function Color:__unm()
    local components = {}
    for _, key in ipairs(self.components) do
        table.insert(components, -self[key])
    end

    local new = self:get_type():new(components)
    return new
end

---Add two colors together, returning a new color with each channel added together
---@param left Color|number
---@param right Color|number
function Color.__add(left, right)
    local self, other = ensure_left_arg_is_color(left, right)

    return self:_per_channel_op(other, function(a, b)
        return a + b
    end)
end

---Subtract two colors, returning a new color with each channel subtracted
---@param left Color|number
---@param right Color|number
function Color.__sub(left, right)
    local self, other = ensure_left_arg_is_color(left, right)

    return self:_per_channel_op(other, function(a, b)
        return a - b
    end)
end

---Multiply two colors together, or a color and a number
---@param left Color|number
---@param right Color|number
function Color.__mul(left, right)
    local self, other = ensure_left_arg_is_color(left, right)

    return self:_per_channel_op(other, function(a, b)
        return a * b
    end)
end

---Divide one color by another color, or a number, returning a new color with each channel divided
---@param left Color|number
---@param right Color|number
function Color.__div(left, right)
    local self, other = ensure_left_arg_is_color(left, right)

    return self:_per_channel_op(other, function(a, b)
        return a / b
    end)
end

function Color.interpolate_linear(a, b, percentage)
    local start = a:to("oklab")
    local finish = b:to("oklab")

    local values = {}
    for _, key in ipairs(start.components) do
        values[key] = start[key] + ((finish[key] - start[key]) * percentage)
    end
    local new = require("polychrome").oklab(values)

    return new:to(getmetatable(a))
end

function Color:__tostring()
    return self:hex()
end

---Get the component values of the color as a plain table
---@return {[string]: number}
function Color:values()
    local parts = {}

    for _, component in ipairs(self.components) do
        table.insert(parts, self[component])
    end

    return parts
end

---Serialize the object to a string representation
---@return string
function Color:serialize()
    return vim.iter({ { self.__type }, self:values() }):flatten():join(":")
end

---Deserialize an object from a string representation
---@param serialized_or_cls Color|string
---@param serialized string
---@return Color
function Color.deserialize(serialized_or_cls, serialized)
    -- allow ".deserialize" or ':deserialize' syntax
    if type(serialized_or_cls) == "string" then
        serialized = serialized_or_cls
    end

    local parts = vim.split(serialized, ":")
    local _type = table.remove(parts, 1)

    local cls = require("polychrome.color")[_type]

    assert(cls, "Type " .. _type .. " does not exist!")

    return cls:new(parts)
end

---Save a conversion to another gamut in the cache
---@param result Color
function Color:_save_conversion_to_cache(result)
    local from = self:serialize()
    local to = result:serialize()

    -- cache from self to result
    COLOR_CACHE[from] = COLOR_CACHE[from] or {}
    COLOR_CACHE[from][result.__type] = result:values()

    -- cache from result to self
    COLOR_CACHE[to] = COLOR_CACHE[to] or {}
    COLOR_CACHE[to][self.__type] = self:values()
end

---Get a cached conversion to another gamut, or nil if it doesn't exist
---@param _type Color
---@return Color?
function Color:_get_conversion_from_cache(_type)
    local key = self:serialize()

    if COLOR_CACHE[key] == nil then
        return nil
    end

    local values = COLOR_CACHE[key][_type.__type]
    if values == nil then
        return nil
    end

    return _type:new(values)
end

---Get a cached conversion to another gamut, or perform and save the conversion to the cache if it doesn't exist
---@param destination_type Color
---@param convert fun(): Color?
---@return Color?
function Color:_get_or_save_conversion_to_cache(destination_type, convert)
    local cached = self:_get_conversion_from_cache(destination_type)
    if cached ~= nil then
        return cached
    end

    local converted = convert()
    if converted == nil then
        return nil
    end
    self:_save_conversion_to_cache(converted)

    return converted
end

---Get the hex representation of the color
---@return string
function Color:hex()
    return self:_get_or_save_conversion_to_cache(require("polychrome.color.rgb"), function()
        return self:to("rgb")
    end):hex()
end

return Color
