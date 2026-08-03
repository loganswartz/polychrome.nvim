local utils = require("polychrome.utils")

local function ensure_left_arg_is_color(left, right)
    -- "number + color" syntax
    if type(left) == "number" then
        return right, left
    end

    -- "color + number" and "color + color" syntax
    return left, right
end

--- Global cache for hex values of colors.
---
--- This is used to avoid recalculating the hex value of a color every time it
--- is used. The key is a combination of the color type and its component
--- values.
local COLOR_CACHE = {}

---@see Reference https://drafts.csswg.org/css-color/#color-conversion-code

---@class Color A generic color that can be converted to a hex value.
---@field __type string
---@field is_color_object boolean
---@field new fun(self: Color, ...: table|number): Color Create a new instance of the class.
---@field components string[] The components of the gamut in the order they are specified.
---@field to_matrix fun(self: Color): Matrix Convert the color to a `<number of components> x 1` matrix.
---@overload fun(self: Color, ...: number): Color Create a new instance of the class.
---@field is fun(self: Color, type: Color|string): boolean Is the color the same type as the argument?
---@field get_type fun(self: Color): Color? Return the class of the color.
---@field get_common_ancestor fun(self: Color, type: Color): Color? Get the common ancestor, if it exists.
---@field get_parent_gamut fun(self: Color): Color? The parent color gamut
---@field parent_chain fun(self: Color): Color[] Return the parent chain of the gamut
---@field _descent_chain fun(self: Color): Color[] Return the descent chain of the gamut
---@field to_parent fun(self: Color): Color? Convert the color to the parent type
---@field from_parent fun(self: Color, parent: Color): Color? Convert the parent type to this type
---@field to fun(self: Color, type: Color|string): Color? Convert the color to another gamut
---@field _to fun(self: Color, type: Color): Color? Convert the color to another gamut, without caching logic
---@field _up fun(self: Color, type: Color): Color Convert the color to a gamut in the parent chain
---@field _down fun(self: Color, type: Color): Color Convert the color to a gamut that has this type as an ancestor
---@field _save_conversion_to_cache fun(self: Color, result: Color): nil Save a conversion to another gamut in the cache
---@field _get_conversion_from_cache fun(self: Color, type: Color): Color? Get a cached conversion to another gamut, or nil if it doesn't exist
---@field _get_or_save_conversion_to_cache fun(self: Color, destination_type: Color, convert: fun(): Color): Color Get a cached conversion to another gamut, or perform and save the conversion to the cache if it doesn't exist
---@field serialize fun(self: Color): string Serialize the object to a string representation
---@field deserialize fun(serialized_or_cls: Color|string, serialized: string?): Color Deserialize an object from a string representation
---@field hex fun(self: Color): string Get the hex representation of the color

---@type Color
local M = { ---@diagnostic disable-line: missing-fields
    is_color_object = true,
    components = {},

    new = function(self, ...)
        local args = { ... }
        local obj = {}

        if #args == 1 and #args[1] == 0 then
            -- `rgb({ r = 50, g = 100, b = 200 })` syntax
            for _, key in ipairs(self.components) do
                obj[key] = args[1][key]
            end
        else
            if #args == 1 and #args[1] > 0 then
                -- `rgb({ 50, 100, 200 })` syntax
                -- convert to `rgb(50, 100, 200)` syntax
                args = args[1]
            end

            -- `rgb(50, 100, 200)` syntax
            for index, value in ipairs(args) do
                local key = self.components[index]
                obj[key] = value
            end
        end

        setmetatable(obj, self)

        return obj
    end,

    to_matrix = function(self)
        local matrix = require("polychrome.matrix")

        local rows = {}
        for _, key in ipairs(self.components) do
            table.insert(rows, self[key])
        end

        return matrix(rows)
    end,

    get_parent_gamut = function()
        return nil
    end,

    is = function(self, _type)
        -- load class dynamically
        if type(_type) == "string" then
            local cls = require("polychrome.color")[_type]
            if cls == nil or not cls.is_color_object then
                error("No gamut found named '" .. _type .. "'.")
            end

            _type = cls
        end

        return self.__type == _type.__type
    end,

    get_type = function(self)
        local color = require("polychrome.color")
        for _, value in pairs(color) do
            if self:is(value) then
                return value
            end
        end

        return nil
    end,

    parent_chain = function(self)
        local chain = {}
        ---@type Color?
        local parent = self:get_parent_gamut()

        while parent ~= nil do
            table.insert(chain, parent)
            parent = parent:get_parent_gamut()
        end

        return chain
    end,

    _descent_chain = function(self)
        local chain = {}
        ---@type Color?
        local current = self

        while current and current:get_parent_gamut() ~= nil do
            table.insert(chain, current)
            current = current:get_parent_gamut()
        end

        return utils.reverse(chain)
    end,

    get_common_ancestor = function(self, other)
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
    end,

    -- perf: cache the hex conversion to avoid recalculating every time the color is used
    to = function(self, _type)
        -- allow passing the name of the gamut as a string
        if type(_type) == "string" then
            local cls = require("polychrome.color")[_type]
            if cls == nil or not cls.is_color_object then
                error("No gamut found named '" .. _type .. "'.")
            end
            _type = cls
        end

        -- if we already have the right type, no-op
        if self:is(_type) then
            return self
        end

        return self:_get_or_save_conversion_to_cache(_type, function()
            return self:_to(_type)
        end)
    end,

    _to = function(self, _type)
        local common = self:get_common_ancestor(_type)
        if common == nil then
            error("Gamuts do not have common ancestors.")
        end

        -- convert up to the root
        local root = self:_up(common)
        -- convert down to the destination type
        return root:_down(_type)
    end,

    _up = function(self, type)
        local path = self:parent_chain()
        local goal = utils.find(path, type, self.is)

        -- already the root
        if goal == nil then
            return self
        end

        local current = self
        for _ = 1, goal, 1 do
            local next = current:to_parent()
            if next == nil then
                error("Got nil when converting " .. current.__type .. " into parent")
            end

            current = next
        end

        return current
    end,

    _down = function(self, type)
        -- going top-down, rather than bottom-up
        local path = type:_descent_chain()

        -- find starting point, skip it if found
        local idx = utils.find(path, self, self.is)
        -- if not found, it must be the root, so just go from the start
        local start = idx ~= nil and idx + 1 or 1

        -- iterate backwards through the path
        local current = self
        for _, t in ipairs(utils.slice(path, start, #path)) do
            local next = t:from_parent(current)
            if next == nil then
                error("Got nil when converting " .. current.__type .. " into child")
            end

            current = next
        end

        return current
    end,

    repr = function(self)
        local repr = self.__type .. "({ "

        repr = repr
            .. vim.iter(self.components)
                :map(function(c)
                    return c .. " = " .. self[c]
                end)
                :join(", ")

        return repr .. " })"
    end,

    _per_channel_op = function(self, other, op)
        local destination_type = self:get_type()

        -- "color + 128" syntax
        if type(other) == "number" then
            other = destination_type:new(other, other, other)
        end
        local other_type = other:get_type()

        local converted = self:clone():to(other_type)

        local components = {}
        for _, key in ipairs(converted.components) do
            table.insert(components, op(converted[key], other[key]))
        end

        return other_type:new(components):to(destination_type)
    end,

    clone = function(self)
        local values = {}
        for _, key in ipairs(self.components) do
            table.insert(values, self[key])
        end

        return self:get_type():new(values)
    end,

    __call = function(self, ...)
        return self:new(...)
    end,

    __eq = function(self, other)
        for _, key in ipairs(self.components) do
            if self[key] ~= other[key] then
                return false
            end
        end

        return true
    end,

    __unm = function(self)
        local components = {}
        for _, key in ipairs(self.components) do
            table.insert(components, -self[key])
        end

        local new = self:get_type():new(components)
        return new
    end,

    __add = function(left, right)
        local self, other = ensure_left_arg_is_color(left, right)

        return self:_per_channel_op(other, function(a, b)
            return a + b
        end)
    end,

    __sub = function(left, right)
        local self, other = ensure_left_arg_is_color(left, right)

        return self:_per_channel_op(other, function(a, b)
            return a - b
        end)
    end,

    __mul = function(left, right)
        local self, other = ensure_left_arg_is_color(left, right)

        return self:_per_channel_op(other, function(a, b)
            return a * b
        end)
    end,

    __div = function(left, right)
        local self, other = ensure_left_arg_is_color(left, right)

        return self:_per_channel_op(other, function(a, b)
            return a / b
        end)
    end,

    interpolate_linear = function(a, b, percentage)
        local start = a:to("oklab")
        local finish = b:to("oklab")

        local values = {}
        for _, key in ipairs(start.components) do
            values[key] = start[key] + ((finish[key] - start[key]) * percentage)
        end
        local new = require("polychrome").oklab(values)

        return new:to(getmetatable(a))
    end,

    __tostring = function(self)
        return self:hex()
    end,

    serialize = function(self)
        local parts = { self.__type }
        for _, component in ipairs(self.components) do
            table.insert(parts, self[component])
        end

        return table.concat(parts, ":")
    end,

    deserialize = function(serialized_or_cls, serialized)
        -- allow ".deserialize" or ':deserialize' syntax
        if type(serialized_or_cls) == "string" then
            serialized = serialized_or_cls
        end

        local parts = vim.split(serialized, ":")
        local _type = table.remove(parts, 1)

        local type = require("polychrome.color")[_type]

        if type == nil then
            error("Type " .. _type .. " dows not exist!")
        end

        return type:new(parts)
    end,

    _save_conversion_to_cache = function(self, result)
        local from = self:serialize()
        local to = result:serialize()

        -- cache from self to result
        COLOR_CACHE[from] = COLOR_CACHE[from] or {}
        COLOR_CACHE[from][result.__type] = to

        -- cache from result to self
        COLOR_CACHE[to] = COLOR_CACHE[to] or {}
        COLOR_CACHE[to][self.__type] = from
    end,

    _get_conversion_from_cache = function(self, type)
        local key = self:serialize()

        if COLOR_CACHE[key] == nil then
            return nil
        end

        local serialized = COLOR_CACHE[key][type.__type]
        if serialized == nil then
            return nil
        end

        return type:deserialize(serialized)
    end,

    _get_or_save_conversion_to_cache = function(self, destination_type, convert)
        local cached = self:_get_conversion_from_cache(destination_type)
        if cached ~= nil then
            return cached
        end

        local converted = convert()
        self:_save_conversion_to_cache(converted)

        return converted
    end,

    hex = function(self)
        return self:_get_or_save_conversion_to_cache(require("polychrome.color.rgb"), function()
            return self:to("rgb")
        end):hex()
    end,
}
M.__index = M

return M
