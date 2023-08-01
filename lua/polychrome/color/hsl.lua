local Color = require('polychrome.color.base').Color
local utils = require('polychrome.utils')

local M = {}

---@class HSL : Color
---@field __type 'hsl'
---@field h number The "hue" value of the color [0-360]
---@field s number The "saturation" value of the color [0-100]
---@field l number The "lightness" value of the color [0-100]
---@field new fun(self: HSL, obj: table?): HSL Create a new instance of the class.
---@overload fun(self: HSL, ...: number): HSL Create a new instance of the class.
---@field hue_to_RGB_value fun(p: number, q: number, t: number): number Convert a hue to an RGB component value
---@field to_RGB fun(self: HSL): RGB Convert the color to gamma-corrected RGB.
---@field to_lRGB fun(self: HSL): lRGB Convert the color to linear RGB.
---@field to_Oklab fun(self: HSL): Oklab Convert the color to Oklab.
---@field to_Oklch fun(self: HSL): Oklch Convert the color to Oklch.

---@type HSL
M.HSL = { ---@diagnostic disable-line: missing-fields
    __type = 'hsl',
    new = utils.new,

    _short_new = function(self, ...)
        local attrs = { ... }

        return self:new({
            h = attrs[1],
            s = attrs[2],
            l = attrs[3],
        })
    end,

    hue_to_RGB_value = function(p, q, t)
        if (t < 0) then t = t + 1 end
        if (t > 1) then t = t - 1 end

        if (t < 1 / 6) then
            return p + (q - p) * 6 * t
        elseif (t < 1 / 2) then
            return q
        elseif (t < 2 / 3) then
            return p + (q - p) * (2 / 3 - t) * 6
        end

        return p
    end,

    to_RGB = function(self)
        local r, g, b

        -- scale to range [0-1]
        local h = self.h / 360
        local s = self.s / 100
        local l = self.l / 100

        -- achromatic
        if (self.s == 0) then
            r = l
            g = l
            b = l
        else
            local q
            if (l < 0.5) then
                q = l * (1 + s)
            else
                q = l + s - l * s
            end

            local p = 2 * l - q;

            r = self.hue_to_RGB_value(p, q, h + 1 / 3)
            g = self.hue_to_RGB_value(p, q, h)
            b = self.hue_to_RGB_value(p, q, h - 1 / 3)
        end

        local RGB = require('polychrome.color.rgb').RGB
        return RGB:new({ r = utils.round(r * 255), g = utils.round(g * 255), b = utils.round(b * 255) })
    end,

    to_lRGB = function(self)
        return self:to_RGB():to_lRGB()
    end,

    to_Oklab = function(self)
        return self:to_lRGB():to_Oklab()
    end,

    to_Oklch = function(self)
        return self:to_Oklab():to_Oklch()
    end,

    ---@param self HSL
    to_hex = function(self)
        return self:to_RGB():to_hex()
    end,
}
M.HSL.__index = M.HSL
setmetatable(M.HSL, Color)

return M
