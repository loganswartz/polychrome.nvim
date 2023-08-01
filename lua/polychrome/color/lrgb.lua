local Color = require('polychrome.color.base').Color
local utils = require('polychrome.utils')

local M = {}

---@class lRGB : Color
---@field __type 'lrgb'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
---@field new fun(self: lRGB, obj: table?): lRGB Create a new instance of the class.
---@overload fun(self: lRGB, ...: number): lRGB Create a new instance of the class.
---@field to_RGB fun(self: lRGB): RGB Convert the color to gamma-corrected RGB.
---@field to_HSL fun(self: lRGB): HSL Convert the color to HSL.
---@field to_Oklab fun(self: lRGB): Oklab Convert the color to Oklab.
---@field to_Oklch fun(self: lRGB): Oklch Convert the color to Oklch.

---@type lRGB
M.lRGB = { ---@diagnostic disable-line: missing-fields
    __type = 'lrgb',
    new = utils.new,

    _short_new = function(self, ...)
        local attrs = { ... }

        return self:new({
            lr = attrs[1],
            lg = attrs[2],
            lb = attrs[3],
        })
    end,

    to_RGB = function(self)
        local RGB = require('polychrome.color.rgb').RGB
        return RGB:new({
            r = utils.round(utils.clamp(utils.linear_to_gamma(self.lr) * 255)),
            g = utils.round(utils.clamp(utils.linear_to_gamma(self.lg) * 255)),
            b = utils.round(utils.clamp(utils.linear_to_gamma(self.lb) * 255)),
        })
    end,

    to_Oklab = function(self)
        local l = 0.4122214708 * self.lr + 0.5363325363 * self.lg + 0.0514459929 * self.lb
        local m = 0.2119034982 * self.lr + 0.6806995451 * self.lg + 0.1073969566 * self.lb
        local s = 0.0883024619 * self.lr + 0.2817188376 * self.lg + 0.6299787005 * self.lb

        local l_ = utils.cuberoot(l)
        local m_ = utils.cuberoot(m)
        local s_ = utils.cuberoot(s)

        local Oklab = require('polychrome.color.oklab').Oklab
        return Oklab:new({
            L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
        })
    end,

    to_Oklch = function(self)
        return self:to_Oklab():to_Oklch()
    end,

    to_HSL = function(self)
        return self:to_RGB():to_HSL()
    end,

    ---@param self lRGB
    to_hex = function(self)
        return self:to_RGB():to_hex()
    end,
}
M.lRGB.__index = M.lRGB
setmetatable(M.lRGB, Color)

return M
