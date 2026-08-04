local Color = require("polychrome.color.base")
local utils = require("polychrome.utils")
local matrices = require("polychrome.color.math.matrices")

---@class Oklab : Color
---@field __type 'oklab'
---@field L number The "lightness" value of the color [0-1]
---@field a number The "a" value of the color [?]
---@field b number The "b" value of the color [?]
local Oklab = {
    __type = "oklab",
    components = { "L", "a", "b" },
}
Oklab.__index = Oklab
setmetatable(Oklab, Color)

function Oklab.get_parent_gamut()
    return require("polychrome.color.lms")
end

function Oklab:to_parent()
    -- transform to l'm's'
    local _lms = matrices.Oklab_to_LMS:mul(self:to_matrix())

    -- cube each individual value
    local lms = _lms:replace(function(e)
        return e ^ 3
    end)
        :transpose()[1]

    return self:get_parent_gamut():new(lms)
end

---@param parent LMS
function Oklab:from_parent(parent)
    -- cube root each individual value
    local _lms = parent:to_matrix():replace(utils.nroot)

    -- transform to lab coordinates
    local lab = matrices.LMS_to_Oklab:mul(_lms):transpose()[1]

    return self:new(lab)
end

function Oklab.__unm(self)
    return Color.__unm(self)
end

function Oklab.__add(self, other)
    return Color.__add(self, other)
end

function Oklab.__sub(self, other)
    return Color.__sub(self, other)
end

function Oklab.__mul(self, other)
    return Color.__mul(self, other)
end

function Oklab.__div(self, other)
    return Color.__div(self, other)
end

return Oklab
