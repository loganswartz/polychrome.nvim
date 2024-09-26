local Color = require('polychrome.color.base')
local matrices = require('polychrome.color.math.matrices')

---@class CIEXYZ : Color
---@field __type 'ciexyz'
---@field X number The "X" value of the color [0-1]
---@field Y number The "Y" value of the color [0-1]
---@field Z number The "Z" value of the color 0-1?]
---@field new fun(self: CIEXYZ, ...: table|number): CIEXYZ Create a new instance of the class.
---@overload fun(self: CIEXYZ, ...: table|number): CIEXYZ Create a new instance of the class.

---@type CIEXYZ
local M = { ---@diagnostic disable-line: missing-fields
    __type = 'ciexyz',
    components = { 'X', 'Y', 'Z' },

    get_parent_gamut = function()
        return require('polychrome.color.lms')
    end,

    ---@param self CIEXYZ
    ---@param parent LMS
    from_parent = function(self, parent)
        -- convert to cone response
        local xyz = matrices.LMS_to_XYZ:mul(parent:to_matrix())

        return self:new(xyz:transpose()[1])
    end,

    ---@param self CIEXYZ
    to_parent = function(self)
        local lms = matrices.XYZ_to_LMS:mul(self:to_matrix())

        return self:get_parent_gamut():new(lms:transpose()[1])
    end,
}
M.__index = M
setmetatable(M, Color)

return M
