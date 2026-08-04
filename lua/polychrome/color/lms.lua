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

function LMS.__unm(self)
    return Color.__unm(self)
end

function LMS.__add(self, other)
    return Color.__add(self, other)
end

function LMS.__sub(self, other)
    return Color.__sub(self, other)
end

function LMS.__mul(self, other)
    return Color.__mul(self, other)
end

function LMS.__div(self, other)
    return Color.__div(self, other)
end

return LMS
