local Color = require('polychrome.color.base')

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
}
M.__index = M
setmetatable(M, Color)

return M
