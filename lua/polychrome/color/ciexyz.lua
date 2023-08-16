local Color = require('polychrome.color.base').Color
local utils = require('polychrome.utils')

local M = {}

---@class CIEXYZ : Color
---@field __type 'ciexyz'
---@field X number The "X" value of the color [0-1]
---@field Y number The "Y" value of the color [0-1]
---@field Z number The "Z" value of the color 0-1?]
---@field new fun(self: CIEXYZ, obj: table?): CIEXYZ Create a new instance of the class.
---@overload fun(self: CIEXYZ, ...: number): CIEXYZ Create a new instance of the class.

---@type CIEXYZ
M.CIEXYZ = { ---@diagnostic disable-line: missing-fields
    __type = 'ciexyz',
    new = utils.new,

    _short_new = function(self, ...)
        local attrs = { ... }

        return self:new({
            X = attrs[1],
            Y = attrs[2],
            Z = attrs[3],
        })
    end,
}
M.CIEXYZ.__index = M.CIEXYZ
setmetatable(M.CIEXYZ, Color)

return M
