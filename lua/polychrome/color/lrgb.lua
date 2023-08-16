local Color = require('polychrome.color.base').Color
local matrix = require('polychrome.matrix')
local utils = require('polychrome.utils')

local M = {}

-- https://en.wikipedia.org/wiki/SRGB#From_CIE_XYZ_to_sRGB
-- Actually use values from https://en.wikipedia.org/wiki/SRGB#sYCC, which are higher precision
M.CIEXYZ_to_lRGB = matrix({
    { 3.2406255,  -1.5372080, -0.4986286 },
    { -0.9689307, 1.8757561,  0.0415175 },
    { 0.0557101,  -0.2040211, 1.0569959 },
})

---@class lRGB : Color
---@field __type 'lrgb'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
---@field new fun(self: lRGB, obj: table?): lRGB Create a new instance of the class.
---@overload fun(self: lRGB, ...: number): lRGB Create a new instance of the class.

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

    get_parent_gamut = function(self)
        return require('polychrome.color.ciexyz').CIEXYZ
    end,

    ---@param self lRGB
    to_parent = function(self)
        local rgb = matrix({
            { self.lr },
            { self.lg },
            { self.lb },
        })
        local xyz = M.CIEXYZ_to_lRGB:invert():mul(rgb):transpose()[1]

        return self:get_parent_gamut():new({
            X = xyz[1],
            Y = xyz[2],
            Z = xyz[3],
        })
    end,

    ---@param self lRGB
    ---@param parent CIEXYZ
    from_parent = function(self, parent)
        local xyz = matrix({
            { parent.X },
            { parent.Y },
            { parent.Z },
        })

        local rgb = M.CIEXYZ_to_lRGB:mul(xyz):transpose()[1]

        return self:new({
            lr = utils.clamp(rgb[1], 0, 1),
            lg = utils.clamp(rgb[2], 0, 1),
            lb = utils.clamp(rgb[3], 0, 1),
        })
    end,
}
M.lRGB.__index = M.lRGB
setmetatable(M.lRGB, Color)

return M
