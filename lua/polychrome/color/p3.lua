local Color = require("polychrome.color.base")
local gamma = require("polychrome.color.math.gamma")

---@class P3 : Color
---@field __type 'p3'
---@field lr number The red value of the color [0-1]
---@field lg number The green value of the color [0-1]
---@field lb number The blue value of the color [0-1]
local P3 = {
    __type = "p3",
    components = { "lr", "lg", "lb" },
    ranges = {
        lr = { 0, 1 },
        lg = { 0, 1 },
        lb = { 0, 1 },
    },
}
P3.__index = P3
setmetatable(P3, Color)

---@return P3_Linear
function P3.get_parent_gamut()
    return require("polychrome.color.linear_p3")
end

---@return P3_Linear
function P3:to_parent()
    local scaled = vim.iter(self:values())
        :map(function(v)
            return gamma.gamma_to_linear(v)
        end)
        :totable()

    return self.get_parent_gamut():new(scaled)
end

---@param parent P3_Linear
function P3.from_parent(self, parent)
    local scaled = vim.iter(parent:values())
        :map(function(v)
            return gamma.linear_to_gamma(v)
        end)
        :totable()

    return self:new(scaled)
end

P3.__tostring = Color.__tostring
P3.__unm = Color.__unm
P3.__eq = Color.__eq
P3.__add = Color.__add
P3.__sub = Color.__sub
P3.__mul = Color.__mul
P3.__div = Color.__div

return P3
