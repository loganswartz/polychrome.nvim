local math = require('math')
local bit = require('bit')

local Color = require('polychrome.color.base').Color
local utils = require('polychrome.utils')

local M = {}

---@class RGB : Color
---@field __type 'rgb'
---@field r number The red value of the color [0-255]
---@field g number The green value of the color [0-255]
---@field b number The blue value of the color [0-255]
---@field new fun(self: RGB, obj: table?): RGB Create a new instance of the class.
---@overload fun(self: RGB, ...: number): RGB Create a new instance of the class.
---@field from_hex fun(input: string): RGB Create an RGB instance from a hex string.
---@field to_hex fun(self: RGB): string Create a hex string representing the color.
---@field to_HSL fun(self: RGB): HSL Convert the color to HSL.
---@field to_lRGB fun(self: RGB): lRGB Convert the color to linear RGB.
---@field to_Oklab fun(self: RGB): Oklab Convert the color to Oklab.
---@field to_Oklch fun(self: RGB): Oklch Convert the color to Oklch.

---@type RGB
M.RGB = { ---@diagnostic disable-line: missing-fields
    __type = 'rgb',
    new = function(self, obj)
        obj = obj or {}
        setmetatable(obj, self)
        obj.r = utils.clamp(obj.r)
        obj.g = utils.clamp(obj.g)
        obj.b = utils.clamp(obj.b)

        return obj
    end,

    _short_new = function(self, ...)
        local attrs = { ... }

        return self:new({
            r = attrs[1],
            g = attrs[2],
            b = attrs[3],
        })
    end,

    from_hex = function(input)
        local hex = input:gsub("%#", "")
        local num = tonumber(hex, 16)

        local RGB = require('polychrome.color.rgb').RGB
        return RGB:new({
            r = bit.rshift(num, 16),
            g = bit.band(bit.rshift(num, 8), 255),
            b = bit.band(num, 255),
        })
    end,

    ---@param self RGB
    to_hex = function(self)
        return "#" .. ("%02x"):format(self.r) .. ("%02x"):format(self.g) .. ("%02x"):format(self.b)
    end,

    to_HSL = function(self)
        -- Make r, g, and b fractions of 1
        local r = self.r / 255
        local g = self.g / 255
        local b = self.b / 255

        -- Find greatest and smallest channel values
        local cmin = math.min(r, g, b)
        local cmax = math.max(r, g, b)
        local delta = cmax - cmin

        -- calculate hue
        local h = 0

        if (delta == 0) then
            h = 0;
        elseif (cmax == r) then
            h = ((g - b) / delta) % 6
        elseif (cmax == g) then
            h = (b - r) / delta + 2
        else
            h = (r - g) / delta + 4
        end

        h = utils.round(h * 60);
        -- Make negative hues positive behind 360°
        if (h < 0) then
            h = h + 360;
        end

        -- Calculate lightness
        local l = (cmax + cmin) / 2;

        -- Calculate saturation
        local s = 0
        if (delta ~= 0) then
            s = delta / (1 - math.abs(2 * l - 1))
        end

        -- Multiply l and s by 100
        s = math.abs(s * 100)
        l = math.abs(l * 100)

        local HSL = require('polychrome.color.hsl').HSL
        return HSL:new({
            h = h,
            s = s,
            l = l,
        })
    end,

    to_lRGB = function(self)
        local lRGB = require('polychrome.color.lRGB').lRGB
        return lRGB:new({
            lr = utils.gamma_to_linear(self.r / 255),
            lg = utils.gamma_to_linear(self.g / 255),
            lb = utils.gamma_to_linear(self.b / 255),
        })
    end,

    to_Oklab = function(self)
        return self:to_lRGB():to_Oklab()
    end,

    to_Oklch = function(self)
        return self:to_Oklab():to_Oklch()
    end,
}
M.RGB.__index = M.RGB
setmetatable(M.RGB, Color)

return M
