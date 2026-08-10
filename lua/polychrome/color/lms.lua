local Color = require("polychrome.color.base")

---@class LMS : Color
---@field __type 'lms'
---@field L number The "long" wavelength value
---@field M number The "medium" wavelength value
---@field S number The "short" wavelength value
local LMS = {
    __type = "lms",
    components = { "L", "M", "S" },
}
LMS.__index = LMS
setmetatable(LMS, Color)

LMS.__unm = Color.__unm
LMS.__eq = Color.__eq
LMS.__add = Color.__add
LMS.__sub = Color.__sub
LMS.__mul = Color.__mul
LMS.__div = Color.__div

return LMS
