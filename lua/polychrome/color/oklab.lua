local Color = require('polychrome.color.base')
local utils = require('polychrome.utils')
local matrices = require('polychrome.color.math.matrices')

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
        return require('polychrome.color.lms')
    end,

    ---@param self Oklab
    to_parent = function(self)
        -- transform to l'm's'
        local _lms = matrices.Oklab_to_LMS:mul(self:to_matrix())

        -- cube each individual value
        local lms = _lms:replace(function(e) return e ^ 3 end):transpose()[1]

        return self:get_parent_gamut():new(lms)
    end,

    ---@param self Oklab
    ---@param parent LMS
    from_parent = function(self, parent)
        -- cube root each individual value
        local _lms = parent:to_matrix():replace(utils.nroot)

        -- transform to lab coordinates
        local lab = matrices.LMS_to_Oklab:mul(_lms):transpose()[1]

        return self:new(lab)
    end,
}
M.__index = M
setmetatable(M, Color)

return M
