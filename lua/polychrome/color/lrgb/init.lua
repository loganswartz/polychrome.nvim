local Color = require('polychrome.color.base')
local matrices = require('polychrome.color.lrgb.matrices')
local utils = require('polychrome.utils')

---@class lRGB : Color
---@field __type 'lrgb'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
---@field new fun(self: lRGB, ...: table|number): lRGB Create a new instance of the class.
---@overload fun(self: lRGB, ...: table|number): lRGB Create a new instance of the class.
---@field _from_oklab_naive fun(self: lRGB, parent: Oklab): lRGB Naively convert from Oklab to lRGB
---@field to_parent fun(self: lRGB): Oklab
---@field get_parent_gamut fun(self: lRGB): Oklab

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

        local _lms = matrices.lRGB_to_LMS:mul(rgb)
        local lms = _lms:replace(utils.nroot)
        local lab = matrices.LMS_to_Oklab:mul(lms):transpose()[1]

        return self:get_parent_gamut():new(lab)
    end,

    ---@param self lRGB
    ---@param parent Oklab
    from_parent = function(self, parent)
        return require('polychrome.color.lrgb.clip').gamut_clip_preserve_chroma(self:_from_oklab_naive(parent))
    end,

    _from_oklab_naive = function(self, parent)
        local lab = parent:to_matrix()

        local lms = matrices.Oklab_to_LMS:mul(lab)
        local _lms = lms:replace(function(e) return e ^ 3 end)
        local lrgb = matrices.LMS_to_lRGB:mul(_lms):transpose()[1]

        return self:new(lrgb)
    end,
}
M.__index = M
setmetatable(M, Color)

return M
