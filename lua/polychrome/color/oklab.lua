local Color = require('polychrome.color.base')
local utils = require('polychrome.utils')
local matrices = require('polychrome.color.lrgb.matrices')

---@class Oklab : Color
---@field __type 'oklab'
---@field L number The "lightness" value of the color [0-1]
---@field a number The "a" value of the color [?]
---@field b number The "b" value of the color [?]
---@field new fun(self: Oklab, ...: table|number): Oklab Create a new instance of the class.
---@overload fun(self: Oklab, ...: table|number): Oklab Create a new instance of the class.

---@type Oklab
local M = { ---@diagnostic disable-line: missing-fields
    __type = 'oklab',
    components = { 'L', 'a', 'b' },

    get_parent_gamut = function()
        return require('polychrome.color.ciexyz')
    end,

    ---@param self Oklab
    to_parent = function(self)
        local lab = self:to_matrix()

        -- transform to l'm's'
        local _lms = matrices.Oklab_to_LMS:mul(lab)

        -- cube each individual value
        local lms = _lms:replace(function(e) return e ^ 3 end)
        -- map
        local xyz = matrices.LMS_to_XYZ:mul(lms):transpose()[1]

        return self:get_parent_gamut():new(xyz)
    end,

    ---@param self Oklab
    ---@param parent CIEXYZ
    from_parent = function(self, parent)
        -- convert to cone response
        local lms = matrices.XYZ_to_LMS:mul(parent:to_matrix())

        -- cube root each individual value
        local _lms = lms:replace(utils.nroot):transpose()

        -- transform to lab coordinates
        local lab = matrices.LMS_to_Oklab:mul(_lms):transpose()

        return self:new(lab[1])
    end,
}
M.__index = M
setmetatable(M, Color)

return M
