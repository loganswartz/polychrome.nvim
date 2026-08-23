local Color = require("polychrome.color.base")
local matrix = require("polychrome.matrix")

local Linear_P3_to_CIEXYZ = matrix({
    { 0.4865709486482162, 0.26566769316909306, 0.1982172852343625 },
    { 0.2289745640697488, 0.6917385218365064, 0.079286914093745 },
    { 0.0000000000000000, 0.04511338185890264, 1.043944368900976 },
})
local CIEXYZ_to_Linear_P3 = Linear_P3_to_CIEXYZ:invert()

---@class Linear_P3 : Color
---@field __type 'linear_p3'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
local Linear_P3 = {
    __type = "linear_p3",
    components = { "lr", "lg", "lb" },
    ranges = {
        lr = { 0, 1 },
        lg = { 0, 1 },
        lb = { 0, 1 },
    },
}
Linear_P3.__index = Linear_P3
setmetatable(Linear_P3, Color)

---@return CIEXYZ
function Linear_P3.get_parent_gamut()
    return require("polychrome.color.ciexyz")
end

---@return CIEXYZ
function Linear_P3:to_parent()
    local ciexyz = Linear_P3_to_CIEXYZ:mul(self:to_matrix()):transpose()[1]
    local scaled = vim.iter(ciexyz)
        :map(function(v)
            return v * 100
        end)
        :totable()

    return self.get_parent_gamut():new(scaled)
end

---@param parent CIEXYZ
function Linear_P3.from_parent(self, parent)
    local linear_p3 = CIEXYZ_to_Linear_P3:mul(parent:to_matrix()):transpose()[1]
    local scaled = vim.iter(linear_p3)
        :map(function(v)
            return v / 100
        end)
        :totable()

    return self:new(scaled)
end

Linear_P3.__tostring = Color.__tostring
Linear_P3.__unm = Color.__unm
Linear_P3.__eq = Color.__eq
Linear_P3.__add = Color.__add
Linear_P3.__sub = Color.__sub
Linear_P3.__mul = Color.__mul
Linear_P3.__div = Color.__div

return Linear_P3
