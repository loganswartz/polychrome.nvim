local Color = require('polychrome.color.base')
local matrices = require('polychrome.color.math.matrices')

---@class lRGB : Color
---@field __type 'lrgb'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
---@field new fun(self: lRGB, ...: table|number): lRGB Create a new instance of the class.
---@overload fun(self: lRGB, ...: table|number): lRGB Create a new instance of the class.
---@field _from_lms_naive fun(self: lRGB, parent: LMS): lRGB Naively convert from Oklab to lRGB
---@field to_parent fun(self: lRGB): LMS
---@field get_parent_gamut fun(): LMS

---@type lRGB
local M = { ---@diagnostic disable-line: missing-fields
    __type = 'lrgb',
    components = { 'lr', 'lg', 'lb' },

    get_parent_gamut = function()
        return require('polychrome.color.lms')
    end,

    ---@param self lRGB
    to_parent = function(self)
        local lms = matrices.lRGB_to_LMS:mul(self:to_matrix())

        return self.get_parent_gamut():new(lms:transpose()[1])
    end,

    ---@param self lRGB
    ---@param parent LMS
    from_parent = function(self, parent)
        local naive = self:_from_lms_naive(parent)

        return require('polychrome.color.math.clip').gamut_clip_preserve_chroma(naive)
    end,

    _from_lms_naive = function(self, parent)
        local lrgb = matrices.LMS_to_lRGB:mul(parent:to_matrix()):transpose()[1]

        return self:new(lrgb)
    end,
}
M.__index = M
setmetatable(M, Color)


return M
