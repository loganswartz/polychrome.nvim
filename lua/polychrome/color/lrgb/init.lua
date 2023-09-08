local Color = require('polychrome.color.base')
local matrix = require('polychrome.matrix')
local utils = require('polychrome.utils')

local lRGB_to_Oklab_M1 = matrix({
    { 0.4122214708, 0.5363325363, 0.0514459929 },
    { 0.2119034982, 0.6806995451, 0.1073969566 },
    { 0.0883024619, 0.2817188376, 0.6299787005 },
})
local lRGB_to_Oklab_M2 = matrix({
    { 0.2104542553, 0.7936177850,  -0.0040720468 },
    { 1.9779984951, -2.4285922050, 0.4505937099 },
    { 0.0259040371, 0.7827717662,  -0.8086757660 },
})

-- we could just invert the arrays above, but hardcoding the inverted
-- matrices gives us *slightly* higher precision and avoids needing to
-- perform that inversion every time we convert from Oklab to lRGB

-- inverse of lRGB_to_Oklab_M2
local Oklab_to_lRGB_M1 = matrix({
    { 1, 0.3963377774,  0.2158037573 },
    { 1, -0.1055613458, -0.0638541728 },
    { 1, -0.0894841775, -1.2914855480 },
})

-- inverse of lRGB_to_Oklab_M1
local Oklab_to_lRGB_M2 = matrix({
    { 4.0767416621,  -3.3077115913, 0.2309699292 },
    { -1.2684380046, 2.6097574011,  -0.3413193965 },
    { -0.0041960863, -0.7034186147, 1.7076147010 },
})

---@class lRGB : Color
---@field __type 'lrgb'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
---@field new fun(self: lRGB, ...: table|number): lRGB Create a new instance of the class.
---@overload fun(self: lRGB, ...: table|number): lRGB Create a new instance of the class.
---@field _from_oklab_naive fun(self: lRGB, parent: Oklab): lRGB Naively convert from Oklab to lRGB
---@field to_parent fun(self: lRGB): Oklab

---@type lRGB
local M = { ---@diagnostic disable-line: missing-fields
    __type = 'lrgb',
    components = { 'lr', 'lg', 'lb' },

    get_parent_gamut = function(self)
        return require('polychrome.color.oklab')
    end,

    ---@param self lRGB
    to_parent = function(self)
        local rgb = self:to_matrix()

        local _lms = lRGB_to_Oklab_M1:mul(rgb):transpose()[1]
        local l, m, s = utils.nroot(_lms[1]), utils.nroot(_lms[2]), utils.nroot(_lms[3])
        local lab = lRGB_to_Oklab_M2:mul(matrix({
            { l },
            { m },
            { s },
        })):transpose()[1]

        return self:get_parent_gamut():new(lab)
    end,

    ---@param self lRGB
    ---@param parent Oklab
    from_parent = function(self, parent)
        return require('polychrome.color.lrgb.clip').gamut_clip_preserve_chroma(self:_from_oklab_naive(parent))
    end,

    _from_oklab_naive = function(self, parent)
        local lab = parent:to_matrix()
        local lms = Oklab_to_lRGB_M1:mul(lab):transpose()[1]

        local lrgb = Oklab_to_lRGB_M2:mul(matrix({
            { lms[1] ^ 3 },
            { lms[2] ^ 3 },
            { lms[3] ^ 3 },
        })):transpose()[1]

        return self:new(lrgb)
    end,
}
M.__index = M
setmetatable(M, Color)

return M
