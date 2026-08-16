local Color = require("polychrome.color.base")
local utils = require("polychrome.utils")

---@class Oklch : Color
---@field __type 'oklch'
---@field L number The "lightness" value of the color [0-1]
---@field c number The "chroma" value of the color [0-1]
---@field h number The "hue" value of the color [0-360]
local Oklch = {
    __type = "oklch",
    components = { "L", "c", "h" },
    ranges = {
        L = { 0, 1 },
        c = { 0, 0.4 },
        h = { 0, 360 },
    },
}
Oklch.__index = Oklch
setmetatable(Oklch, Color)

function Oklch.get_parent_gamut()
    return require("polychrome.color.oklab")
end

function Oklch:to_parent()
    return self:get_parent_gamut():new({
        L = self.L,
        a = self.c * math.cos(self.h * math.pi / 180),
        b = self.c * math.sin(self.h * math.pi / 180),
    })
end

---@param parent Oklab
function Oklch:from_parent(parent)
    return self:new({
        L = parent.L,
        c = math.sqrt(math.pow(parent.a, 2) + math.pow(parent.b, 2)),
        h = utils.clamp(math.atan2(parent.b, parent.a) * 180 / math.pi, 0, 360),
    })
end

Oklch.__tostring = Color.__tostring
Oklch.__unm = Color.__unm
Oklch.__eq = Color.__eq
Oklch.__add = Color.__add
Oklch.__sub = Color.__sub
Oklch.__mul = Color.__mul
Oklch.__div = Color.__div

return Oklch
