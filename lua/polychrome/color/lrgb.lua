local Color = require("polychrome.color.base")
local matrices = require("polychrome.color.math.matrices")

---@class lRGB : Color
---@field __type 'lrgb'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
local lRGB = {
    __type = "lrgb",
    components = { "lr", "lg", "lb" },
}
lRGB.__index = lRGB
setmetatable(lRGB, Color)

---@return LMS
function lRGB.get_parent_gamut()
    return require("polychrome.color.lms")
end

---@return LMS
function lRGB:to_parent()
    local lms = matrices.lRGB_to_LMS:mul(self:to_matrix())

    return self.get_parent_gamut():new(lms:transpose()[1])
end

---@param parent LMS
function lRGB.from_parent(self, parent)
    local naive = self:_from_lms_naive(parent)

    return require("polychrome.color.math.clip").gamut_clip_preserve_chroma(naive)
end

---Naively convert from Oklab to lRGB
---@param parent LMS
---@return lRGB
function lRGB._from_lms_naive(self, parent)
    local lrgb = matrices.LMS_to_lRGB:mul(parent:to_matrix()):transpose()[1]

    return self:new(lrgb)
end

function lRGB.__unm(self)
    return Color.__unm(self)
end

function lRGB.__add(self, other)
    return Color.__add(self, other)
end

function lRGB.__sub(self, other)
    return Color.__sub(self, other)
end

function lRGB.__mul(self, other)
    return Color.__mul(self, other)
end

function lRGB.__div(self, other)
    return Color.__div(self, other)
end

return lRGB
