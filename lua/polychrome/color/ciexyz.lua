local Color = require("polychrome.color.base")
local matrices = require("polychrome.color.math.matrices")
local matrix = require("polychrome.matrix")

local CIEXYZ_to_LMS = matrix({
    { 0.7328, 0.4296, -0.16239999999998 },
    { -0.7036, 1.6975, 0.0060999999999971 },
    { 0.003, 0.013599999999999, 0.9834 },
})
local LMS_to_CIEXYZ = CIEXYZ_to_LMS:invert()

---@class CIEXYZ : Color
---@field __type 'ciexyz'
---@field X number The "X" value of the color [0-1]
---@field Y number The "Y" value of the color [0-1]
---@field Z number The "Z" value of the color [0-1?]
local CIEXYZ = {
    __type = "ciexyz",
    components = { "X", "Y", "Z" },
    ranges = {
        X = { 0, 100 },
        Y = { 0, 105 },
        Z = { 0, 110 },
    },
}
CIEXYZ.__index = CIEXYZ
setmetatable(CIEXYZ, Color)

function CIEXYZ.get_parent_gamut()
    return require("polychrome.color.lms")
end

---@param parent LMS
function CIEXYZ:from_parent(parent)
    -- convert to cone response
    local xyz = LMS_to_CIEXYZ:mul(parent:to_matrix())

    return self:new(xyz:transpose()[1])
end

function CIEXYZ:to_parent()
    local lms = CIEXYZ_to_LMS:mul(self:to_matrix())

    return self:get_parent_gamut():new(lms:transpose()[1])
end

CIEXYZ.__tostring = Color.__tostring
CIEXYZ.__unm = Color.__unm
CIEXYZ.__eq = Color.__eq
CIEXYZ.__add = Color.__add
CIEXYZ.__sub = Color.__sub
CIEXYZ.__mul = Color.__mul
CIEXYZ.__div = Color.__div

return CIEXYZ
