local Color = require("polychrome.color.base")
local matrices = require("polychrome.color.math.matrices")

---@class CIEXYZ : Color
---@field __type 'ciexyz'
---@field X number The "X" value of the color [0-1]
---@field Y number The "Y" value of the color [0-1]
---@field Z number The "Z" value of the color [0-1?]
local CIEXYZ = {
    __type = "ciexyz",
    components = { "X", "Y", "Z" },
}
CIEXYZ.__index = CIEXYZ
setmetatable(CIEXYZ, Color)

function CIEXYZ.get_parent_gamut()
    return require("polychrome.color.lms")
end

---@param parent LMS
function CIEXYZ:from_parent(parent)
    -- convert to cone response
    local xyz = matrices.LMS_to_XYZ:mul(parent:to_matrix())

    return self:new(xyz:transpose()[1])
end

function CIEXYZ:to_parent()
    local lms = matrices.XYZ_to_LMS:mul(self:to_matrix())

    return self:get_parent_gamut():new(lms:transpose()[1])
end

CIEXYZ.__unm = Color.__unm
CIEXYZ.__eq = Color.__eq
CIEXYZ.__add = Color.__add
CIEXYZ.__sub = Color.__sub
CIEXYZ.__mul = Color.__mul
CIEXYZ.__div = Color.__div

return CIEXYZ
