local Color = require("polychrome.color.base")
local matrix = require("polychrome.matrix")

local lRGB_to_CIEXYZ = matrix({
    { 0.41239079926595, 0.35758433938387, 0.18048078840183 },
    { 0.21263900587151, 0.71516867876775, 0.072192315360733 },
    { 0.019330818715591, 0.11919477979462, 0.95053215224966 },
})
local CIEXYZ_to_lRGB = lRGB_to_CIEXYZ:invert()

---@class lRGB : Color
---@field __type 'lrgb'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
local lRGB = {
    __type = "lrgb",
    components = { "lr", "lg", "lb" },
    ranges = {
        lr = { 0, 1 },
        lg = { 0, 1 },
        lb = { 0, 1 },
    },
}
lRGB.__index = lRGB
setmetatable(lRGB, Color)

---@return CIEXYZ
function lRGB.get_parent_gamut()
    return require("polychrome.color.ciexyz")
end

---@return CIEXYZ
function lRGB:to_parent()
    local ciexyz = lRGB_to_CIEXYZ:mul(self:to_matrix()):transpose()[1]
    local scaled = vim.iter(ciexyz)
        :map(function(v)
            return v * 100
        end)
        :totable()

    return self.get_parent_gamut():new(scaled)
end

---@param parent CIEXYZ
function lRGB.from_parent(self, parent)
    local naive = self:_from_ciexyz_naive(parent)

    return require("polychrome.color.math.clip").gamut_clip_preserve_chroma(naive)
end

---Naively convert from Oklab to lRGB
---@param parent CIEXYZ
---@return lRGB
function lRGB._from_ciexyz_naive(self, parent)
    local lrgb = CIEXYZ_to_lRGB:mul(parent:to_matrix()):transpose()[1]
    local scaled = vim.iter(lrgb)
        :map(function(v)
            return v / 100
        end)
        :totable()

    return self:new(scaled)
end

lRGB.__tostring = Color.__tostring
lRGB.__unm = Color.__unm
lRGB.__eq = Color.__eq
lRGB.__add = Color.__add
lRGB.__sub = Color.__sub
lRGB.__mul = Color.__mul
lRGB.__div = Color.__div

return lRGB
