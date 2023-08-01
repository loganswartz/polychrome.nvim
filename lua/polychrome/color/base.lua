local utils = require('polychrome.utils')

---@see Reference https://drafts.csswg.org/css-color/#color-conversion-code
local M = {}

---@class Color A generic color that can be converted to a hex value.
---@field __type string
---@field is_color_object boolean
---@field new fun(self: Color, obj: table?): Color Create a new instance of the class.
---@field _short_new fun(self: Color, ...: number): Color Create a new instance of the class.
---@overload fun(self: Color, ...: number): Color Create a new instance of the class.
---@field is fun(self: Color, type: Color): boolean Is the color the same type as the argument?
---@field get_type fun(self: Color): Color? Return the class of the color.
---@field to_hex fun(self: Color): string

---@type Color
M.Color = { ---@diagnostic disable-line: missing-fields
    is_color_object = true,

    to_hex = function(self)
        error("Not implemented.")
    end,

    new = utils.new,

    _short_new = function(self)
        error("Not implemented.")
    end,

    __call = function(self, ...)
        return self:_short_new(...)
    end,

    is = function(self, type)
        return self.__type == type.__type
    end,

    get_type = function(self)
        for _, value in pairs({ M.HSL, M.RGB, M.lRGB, M.Oklab, M.Oklch }) do
            if self:is(value) then
                return value
            end
        end

        return nil
    end,
}
M.Color.__index = M.Color

return M
