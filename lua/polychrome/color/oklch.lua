local Color = require('polychrome.color.base')
local utils = require('polychrome.utils')

---@class Oklch : Color
---@field __type 'oklch'
---@field L number The "lightness" value of the color [0-1]
---@field c number The "chroma" value of the color [0-1]
---@field h number The "hue" value of the color [0-360]
---@field new fun(self: Oklch, ...: table|number): Oklch Create a new instance of the class.
---@overload fun(self: Oklch, ...: table|number): Oklch Create a new instance of the class.

---@type Oklch
local M = { ---@diagnostic disable-line: missing-fields
    __type = 'oklch',
    components = { 'L', 'c', 'h' },

    get_parent_gamut = function()
        return require('polychrome.color.oklab')
    end,

    ---@param self Oklch
    to_parent = function(self)
        return self:get_parent_gamut():new({
            L = self.L,
            a = self.c * math.cos(self.h * math.pi / 180),
            b = self.c * math.sin(self.h * math.pi / 180),
        })
    end,

    ---@param self Oklch
    ---@param parent Oklab
    from_parent = function(self, parent)
        return self:new({
            L = parent.L,
            c = math.sqrt(math.pow(parent.a, 2) + math.pow(parent.b, 2)),
            h = utils.clamp(math.atan2(parent.b, parent.a) * 180 / math.pi, 0, 360),
        })
    end,
}
M.__index = M
setmetatable(M, Color)

return M
