local bit = require('bit')

local Color = require('polychrome.color.base')
local utils = require('polychrome.utils')
local gamma = require('polychrome.color.math.gamma')

---@class RGB : Color
---@field __type 'rgb'
---@field r number The red value of the color [0-255]
---@field g number The green value of the color [0-255]
---@field b number The blue value of the color [0-255]
---@field new fun(self: RGB, ...: table|number): RGB Create a new instance of the class.
---@overload fun(self: RGB, ...: table|number): RGB Create a new instance of the class.
---@field from_hex fun(self: RGB, input: string): RGB Create an RGB instance from a hex string.
---@field hex fun(self: RGB): string Create a hex string representing the color.

---@type RGB
local M = { ---@diagnostic disable-line: missing-fields
    __type = 'rgb',
    components = { 'r', 'g', 'b' },

    new = function(self, ...)
        local obj = getmetatable(self).new(self, ...)

        obj.r = utils.clamp(obj.r)
        obj.g = utils.clamp(obj.g)
        obj.b = utils.clamp(obj.b)

        return obj
    end,

    from_hex = function(self, input)
        local hex = input:gsub("%#", "")
        local num = tonumber(hex, 16)

        return self:new({
            r = bit.rshift(num, 16),
            g = bit.band(bit.rshift(num, 8), 255),
            b = bit.band(num, 255),
        })
    end,

    ---@param self RGB
    hex = function(self)
        return "#" .. ("%02x"):format(self.r) .. ("%02x"):format(self.g) .. ("%02x"):format(self.b)
    end,

    get_parent_gamut = function()
        return require('polychrome.color.lrgb')
    end,

    ---@param self RGB
    to_parent = function(self)
        local lRGB = require('polychrome.color.lrgb')
        return lRGB:new({
            lr = gamma.gamma_to_linear(self.r / 255),
            lg = gamma.gamma_to_linear(self.g / 255),
            lb = gamma.gamma_to_linear(self.b / 255),
        })
    end,

    ---@param self RGB
    ---@param parent lRGB
    from_parent = function(self, parent)
        return self:new({
            r = utils.round(utils.clamp(gamma.linear_to_gamma(parent.lr) * 255)),
            g = utils.round(utils.clamp(gamma.linear_to_gamma(parent.lg) * 255)),
            b = utils.round(utils.clamp(gamma.linear_to_gamma(parent.lb) * 255)),
        })
    end,
}
M.__index = M
setmetatable(M, Color)

return M
