local Color = require("polychrome.color.base")
local utils = require("polychrome.utils")
local matrices = require("polychrome.color.math.matrices")
local matrix = require("polychrome.matrix")

local Oklab_to_LMS = matrix({
    { 1.0, 0.3963377773761749, 0.21580375730991364 },
    { 1.0, -0.10556134581565857, -0.0638541728258133 },
    { 1.0, -0.08948418498039246, -1.2914855480194092 },
})
local LMS_to_Oklab = Oklab_to_LMS:invert()

local LMS_to_CIEXYZ = matrix({
    { 1.2270138511, -0.5577999807, 0.2812561490 },
    { -0.0405801784, 1.1122568696, -0.0716766787 },
    { -0.0763812845, -0.4214819784, 1.5861632204 },
})
local CIEXYZ_to_LMS = LMS_to_CIEXYZ:invert()

---@class Oklab : Color
---@field __type 'oklab'
---@field L number The "lightness" value of the color [0-1]
---@field a number The "a" value of the color [?]
---@field b number The "b" value of the color [?]
local Oklab = {
    __type = "oklab",
    components = { "L", "a", "b" },
    ranges = {
        L = { 0, 1 },
        a = { -0.4, 0.4 },
        b = { -0.4, 0.4 },
    },
}
Oklab.__index = Oklab
setmetatable(Oklab, Color)

function Oklab.get_parent_gamut()
    return require("polychrome.color.ciexyz")
end

function Oklab:to_parent()
    -- transform to l'm's'
    local _lms = Oklab_to_LMS:mul(self:to_matrix())

    -- cube each individual value
    local lms = _lms:replace(function(e)
        return e ^ 3
    end)

    local xyz = LMS_to_CIEXYZ:mul(lms):transpose():replace(function(n)
        return n * 100
    end)[1]

    return self:get_parent_gamut():new(xyz)
end

---@param parent CIEXYZ
function Oklab:from_parent(parent)
    local xyz = parent:to_matrix():replace(function(n)
        return n / 100
    end)

    -- convert to LMS and cube root each individual value
    local lms = CIEXYZ_to_LMS:mul(xyz):replace(utils.nroot)

    -- transform to lab coordinates
    local lab = LMS_to_Oklab:mul(lms):transpose()[1]

    return self:new(lab)
end

Oklab.__tostring = Color.__tostring
Oklab.__unm = Color.__unm
Oklab.__eq = Color.__eq
Oklab.__add = Color.__add
Oklab.__sub = Color.__sub
Oklab.__mul = Color.__mul
Oklab.__div = Color.__div

return Oklab
