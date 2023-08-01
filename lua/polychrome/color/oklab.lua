local Color = require('polychrome.color.base').Color
local utils = require('polychrome.utils')

local M = {}

---@class Oklab : Color
---@field __type 'oklab'
---@field L number The "lightness" value of the color [0-1]
---@field a number The "a" value of the color [?]
---@field b number The "b" value of the color [?]
---@field new fun(self: Oklab, obj: table?): Oklab Create a new instance of the class.
---@overload fun(self: Oklab, ...: number): Oklab Create a new instance of the class.
---@field to_Oklch fun(self: Oklab): Oklch Convert the color to Oklch.
---@field to_lRGB fun(self: Oklab): lRGB Convert the color to lRGB.
---@field to_RGB fun(self: Oklab): RGB Convert the color to RGB.
---@field to_HSL fun(self: Oklab): HSL Convert the color to HSL.

---@type Oklab
M.Oklab = { ---@diagnostic disable-line: missing-fields
    __type = 'oklab',
    new = utils.new,

    _short_new = function(self, ...)
        local attrs = { ... }

        return self:new({
            L = attrs[1],
            a = attrs[2],
            b = attrs[3],
        })
    end,

    to_Oklch = function(self)
        local Oklch = require('polychrome.color.oklch').Oklch
        return Oklch:new({
            L = self.L,
            c = math.sqrt(math.pow(self.a, 2) + math.pow(self.b, 2)),
            h = utils.clamp(math.atan2(self.b, self.a) * 180 / math.pi, 0, 360),
        })
    end,

    to_lRGB = function(self)
        local l_ = self.L + 0.3963377774 * self.a + 0.2158037573 * self.b
        local m_ = self.L - 0.1055613458 * self.a - 0.0638541728 * self.b
        local s_ = self.L - 0.0894841775 * self.a - 1.2914855480 * self.b

        local l = math.pow(l_, 3)
        local m = math.pow(m_, 3)
        local s = math.pow(s_, 3)

        local lr = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        local lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        local lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        local lRGB = require('polychrome.color.lrgb').lRGB
        return lRGB:new({
            lr = lr,
            lg = lg,
            lb = lb,
        })
    end,

    to_RGB = function(self)
        return self:to_lRGB():to_RGB()
    end,

    to_HSL = function(self)
        return self:to_RGB():to_HSL()
    end,

    ---@param self Oklab
    to_hex = function(self)
        return self:to_RGB():to_hex()
    end,
}
M.Oklab.__index = M.Oklab
setmetatable(M.Oklab, Color)

return M
