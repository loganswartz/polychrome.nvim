local utils = require('polychrome.utils')

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
---@field is fun(self: Color, type: Color): boolean Is the color the same type as the argument?
---@field get_type fun(self: Color): Color? Return the class of the color.
---@field get_common_ancestor fun(self: Color, type: Color): Color? Get the common ancestor, if it exists.
---@field get_parent_gamut fun(self: Color): Color? The parent color gamut
---@field parent_chain fun(self: Color): Color[] Return the parent chain of the gamut
---@field _descent_chain fun(self: Color): Color[] Return the descent chain of the gamut
---@field to_parent fun(self: Color): Color? Convert the color to the parent type
---@field from_parent fun(self: Color, parent: Color): Color? Convert the parent type to this type
---@field to fun(self: Color, type: Color|string): Color? Convert the color to another gamut
---@field _up fun(self: Color, type: Color): Color Convert the color to a gamut in the parent chain
---@field _down fun(self: Color, type: Color): Color Convert the color to a gamut that has this type as an ancestor
---@field hex fun(self: Color): string

---@type Color
local M = { ---@diagnostic disable-line: missing-fields
    is_color_object = true,
    components = nil,

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

    __call = function(self, ...)
        return self:new(...)
    end,

    to_matrix = function(self)
        local matrix = require('polychrome.matrix')

        local rows = {}
        for _, key in ipairs(self.components) do
            table.insert(rows, self[key])
        end

        return matrix(rows)
    end,

    get_parent_gamut = function()
        return nil
    end,

    is = function(self, type)
        return self.__type == type.__type
    end,

    get_type = function(self)
        local color = require('polychrome.color')
        for _, value in pairs({ color.hsl, color.rgb, color.lrgb, color.oklab, color.oklch, color.ciexyz }) do
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

    to = function(self, _type)
        -- allow passing the name of the gamut as a string
        if type(_type) == 'string' then
            local temp = require('polychrome')[_type]
            if temp == nil or not temp.is_color_object then
                error("No gamut found named '" .. _type .. "'.")
            end
            _type = temp
        end

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
        -- if we already have the right type, no-op
        if self:is(type) then
            return self
        end

        local path = self:parent_chain()
        local goal = utils.find(path, type, self.is)

        -- already the root
        if goal == nil then
            return self
        end

        local current = self
        for _ = 1, goal, 1 do
            current = current:to_parent()
        end

        return current
    end,

    _down = function(self, type)
        -- if we already have the right type, no-op
        if self:is(type) then
            return self
        end

        -- going top-down, rather than bottom-up
        local path = type:_descent_chain()

        -- find starting point, skip it if found
        local idx = utils.find(path, self, self.is)
        -- if not found, it must be the root, so just go from the start
        local start = idx ~= nil and idx + 1 or 1

        -- iterate backwards through the path
        local current = self
        for _, t in ipairs(utils.slice(path, start, #path)) do
            current = t:from_parent(current)
        end

        return current
    end,

    __eq = function(a, b)
        for _, key in ipairs(a.components) do
            if a[key] ~= b[key] then
                return false
            end
        end

        return true
    end,

    interpolate_linear = function(a, b, percentage)
        local start = a:to('oklab')
        local finish = b:to('oklab')

        local values = {}
        for _, key in ipairs(start.components) do
            values[key] = start[key] + ((finish[key] - start[key]) * percentage)
        end
        local new = require('polychrome').oklab(values)

        return new:to(getmetatable(a))
    end,

    __tostring = function(self)
        return self:hex()
    end,

    -- perf: cache the hex conversion to avoid recalculating every time the color is used
    hex = function(self)
        local parts = { self.__type }
        for _, component in ipairs(self.components) do
            table.insert(parts, self[component])
        end
        local key = table.concat(parts, ':')

        if COLOR_CACHE[key] == nil then
            COLOR_CACHE[key] = self:to('rgb'):hex()
        end

        return COLOR_CACHE[key]
    end,
}
M.__index = M

return M
