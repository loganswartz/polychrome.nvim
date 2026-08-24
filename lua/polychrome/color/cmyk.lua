local Color = require("polychrome.color.base")

---@class CMYK : Color
---@field __type 'cmyk'
---@field c number The cyan value of the color
---@field y number The yellow value of the color
---@field m number The magenta value of the color
---@field k number The key value of the color
local M = {
    __type = "cmyk",
    components = { "c", "m", "y", "k" },
    ranges = {
        c = { 0, 100 },
        m = { 0, 100 },
        y = { 0, 100 },
        k = { 0, 100 },
    },
}
M.__index = M
setmetatable(M, Color)

function M.get_parent_gamut()
    return require("polychrome.color.rgb")
end

function M:to_parent()
    local RGB = require("polychrome.color.rgb")

    local c = self.c / 100
    local m = self.m / 100
    local y = self.y / 100
    local k = self.k / 100

    return RGB:new({
        r = (1 - math.min(1, c * (1 - k) + k)) * 255,
        g = (1 - math.min(1, m * (1 - k) + k)) * 255,
        b = (1 - math.min(1, y * (1 - k) + k)) * 255,
    })
end

---@param parent RGB
function M:from_parent(parent)
    local r = parent.r / 255
    local g = parent.g / 255
    local b = parent.b / 255

    local k = math.min(1 - r, 1 - g, 1 - b)
    local c = k == 1 and 0 or ((1 - r - k) / (1 - k)) or 0
    local m = k == 1 and 0 or ((1 - g - k) / (1 - k)) or 0
    local y = k == 1 and 0 or ((1 - b - k) / (1 - k)) or 0

    return self:new({
        c = c * 100,
        m = m * 100,
        y = y * 100,
        k = k * 100,
    })
end

M.__tostring = Color.__tostring
M.__unm = Color.__unm
M.__eq = Color.__eq
M.__add = Color.__add
M.__sub = Color.__sub
M.__mul = Color.__mul
M.__div = Color.__div

return M
