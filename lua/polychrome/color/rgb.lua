local bit = require("bit")

local Color = require("polychrome.color.base")
local utils = require("polychrome.utils")
local gamma = require("polychrome.color.math.gamma")

---@class RGB : Color
---@field __type 'rgb'
---@field r number The red value of the color [0-255]
---@field g number The green value of the color [0-255]
---@field b number The blue value of the color [0-255]
local M = {
    __type = "rgb",
    components = { "r", "g", "b" },
}
M.__index = M
setmetatable(M, Color)

---Create a new instance of the class.
---@param ... table|number
---@return RGB
function M.new(self, ...)
    local obj = getmetatable(self).new(self, ...)

    obj.r = utils.clamp(obj.r)
    obj.g = utils.clamp(obj.g)
    obj.b = utils.clamp(obj.b)

    return obj
end

---Create an RGB instance from a hex string.
---@param input string
---@return RGB
function M:from_hex(input)
    local hex = input:gsub("%#", "")
    local num = tonumber(hex, 16)

    return self:from_number(num)
end

---Create an RGB instance from a raw number.
---@param input number
---@return RGB
function M:from_number(input)
    return self:new({
        r = bit.rshift(input, 16),
        g = bit.band(bit.rshift(input, 8), 255),
        b = bit.band(input, 255),
    })
end

---Create a hex string representing the color.
---@return string
function M:hex()
    return "#" .. ("%02x"):format(self.r) .. ("%02x"):format(self.g) .. ("%02x"):format(self.b)
end

function M.get_parent_gamut()
    return require("polychrome.color.lrgb")
end

function M:to_parent()
    local lRGB = require("polychrome.color.lrgb")
    return lRGB:new({
        lr = gamma.gamma_to_linear(self.r / 255),
        lg = gamma.gamma_to_linear(self.g / 255),
        lb = gamma.gamma_to_linear(self.b / 255),
    })
end

---@param parent lRGB
function M:from_parent(parent)
    return self:new({
        r = utils.round(utils.clamp(gamma.linear_to_gamma(parent.lr) * 255)),
        g = utils.round(utils.clamp(gamma.linear_to_gamma(parent.lg) * 255)),
        b = utils.round(utils.clamp(gamma.linear_to_gamma(parent.lb) * 255)),
    })
end

function M.__unm(self)
    return Color.__unm(self)
end

function M.__add(self, other)
    return Color.__add(self, other)
end

function M.__sub(self, other)
    return Color.__sub(self, other)
end

function M.__mul(self, other)
    return Color.__mul(self, other)
end

function M.__div(self, other)
    return Color.__div(self, other)
end

return M
