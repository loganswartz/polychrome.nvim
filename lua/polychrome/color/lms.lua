local Color = require('polychrome.color.base')

---@class LMS : Color
---@field __type 'lms'
---@field L number The "long" wavelength value
---@field M number The "medium" wavelength value
---@field S number The "short" wavelength value
---@field new fun(self: LMS, ...: table|number): LMS Create a new instance of the class.
---@overload fun(self: LMS, ...: table|number): LMS Create a new instance of the class.

---@type LMS
local M = { ---@diagnostic disable-line: missing-fields
    __type = 'lms',
    components = { 'L', 'M', 'S' },
}
M.__index = M
setmetatable(M, Color)

return M
