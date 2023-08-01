local Color = require('polychrome.color.base').Color
local utils = require('polychrome.utils')

local M = {}

---@class Oklch : Color
---@field __type 'oklch'
---@field L number The "lightness" value of the color [0-1]
---@field c number The "chroma" value of the color [0-1]
---@field h number The "hue" value of the color [0-360]
---@field new fun(self: Oklch, obj: table): Oklch Create a new instance of the class.
---@overload fun(self: Oklch, ...: number): Oklch Create a new instance of the class.
---@field to_Oklab fun(self: Oklch): Oklab Convert the color to Oklab.
---@field to_lRGB fun(self: Oklch): lRGB Convert the color to lRGB.
---@field to_RGB fun(self: Oklch): RGB Convert the color to RGB.
---@field to_HSL fun(self: Oklch): HSL Convert the color to HSL.

---@type Oklch
M.Oklch = { ---@diagnostic disable-line: missing-fields
    __type = 'oklch',
    new = utils.new,

    _short_new = function(self, ...)
        local attrs = { ... }

        return self:new({
            L = attrs[1],
            c = attrs[2],
            h = attrs[3],
        })
    end,

    to_Oklab = function(self)
        local Oklab = require('polychrome.color.oklab').Oklab
        return Oklab:new({
            L = self.L,
            a = self.c * math.cos(self.h * math.pi / 180),
            b = self.c * math.sin(self.h * math.pi / 180),
        })
    end,

    to_lRGB = function(self)
        return self:to_Oklab():to_lRGB()
    end,

    to_RGB = function(self)
        return self:to_lRGB():to_RGB()
    end,

    to_HSL = function(self)
        return self:to_RGB():to_HSL()
    end,

    ---@param self Oklch
    to_hex = function(self)
        return self:to_RGB():to_hex()
    end,
}
M.Oklch.__index = M.Oklch
setmetatable(M.Oklch, Color)

return M
