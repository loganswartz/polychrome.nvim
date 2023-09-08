local Color = require('polychrome.color.base')
local utils = require('polychrome.utils')

---@class HSL : Color
---@field __type 'hsl'
---@field h number The "hue" value of the color [0-360]
---@field s number The "saturation" value of the color [0-100]
---@field l number The "lightness" value of the color [0-100]
---@field new fun(self: HSL, ...: table|number): HSL Create a new instance of the class.
---@overload fun(self: HSL, ...: table|number): HSL Create a new instance of the class.
---@field hue_to_RGB_value fun(p: number, q: number, t: number): number Convert a hue to an RGB component value

---@type HSL
local M = { ---@diagnostic disable-line: missing-fields
    __type = 'hsl',
    components = { 'h', 's', 'l' },

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

    get_parent_gamut = function(self)
        return require('polychrome.color.rgb')
    end,

    ---@param self HSL
    to_parent = function(self)
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

        return self:get_parent_gamut():new({
            r = utils.round(r * 255),
            g = utils.round(g * 255),
            b = utils.round(b * 255),
        })
    end,

    ---@param self HSL
    ---@param parent RGB
    from_parent = function(self, parent)
        -- Make r, g, and b fractions of 1
        local r = parent.r / 255
        local g = parent.g / 255
        local b = parent.b / 255

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

        return self:new(h, s, l)
    end,
}
M.__index = M
setmetatable(M, Color)

return M
