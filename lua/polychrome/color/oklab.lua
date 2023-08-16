local Color = require('polychrome.color.base').Color
local utils = require('polychrome.utils')
local matrix = require('polychrome.matrix')

local M = {}

-- https://bottosson.github.io/posts/oklab/#converting-from-xyz-to-oklab
M.Oklab_to_XYZ_M1 = matrix({
    { 0.8189330101, 0.3618667424, -0.1288597137 },
    { 0.0329845436, 0.9293118715, 0.0361456387 },
    { 0.0482003018, 0.2643662691, 0.6338517070 }
})
M.Oklab_to_XYZ_M2 = matrix({
    { 0.2104542553, 0.7936177850,  -0.0040720468 },
    { 1.9779984951, -2.4285922050, 0.4505937099 },
    { 0.0259040371, 0.7827717662,  -0.8086757660 }
})

---@class Oklab : Color
---@field __type 'oklab'
---@field L number The "lightness" value of the color [0-1]
---@field a number The "a" value of the color [?]
---@field b number The "b" value of the color [?]
---@field new fun(self: Oklab, obj: table?): Oklab Create a new instance of the class.
---@overload fun(self: Oklab, ...: number): Oklab Create a new instance of the class.

---@type Oklab
M.Oklab = { ---@diagnostic disable-line: missing-fields
    __type = 'oklab',
    new = utils.new,

    _short_new = function(self, ...)
        local attrs = { ... }

        return self:new({
            L = attrs[1],
            a = attrs[2],
            b = attrs[3],
        })
    end,

    get_parent_gamut = function()
        return require('polychrome.color.ciexyz').CIEXYZ
    end,

    ---@param self Oklab
    to_parent = function(self)
        local lab = matrix({
            { self.L },
            { self.a },
            { self.b },
        })

        -- transform to l'm's'
        local _lms = M.Oklab_to_XYZ_M2:invert():mul(lab):transpose()[1]

        -- cube each individual value
        local lms = matrix({
            { _lms[1] ^ 3 },
            { _lms[2] ^ 3 },
            { _lms[3] ^ 3 },
        })

        -- map
        local xyz = M.Oklab_to_XYZ_M1:invert():mul(lms):transpose()[1]

        local CIEXYZ = require('polychrome.color.ciexyz').CIEXYZ
        return CIEXYZ:new({
            X = xyz[1],
            Y = xyz[2],
            Z = xyz[3],
        })
    end,

    ---@param self Oklab
    ---@param parent CIEXYZ
    from_parent = function(self, parent)
        -- convert to cone response
        local lms = M.Oklab_to_XYZ_M1:mul(matrix({
            { parent.X },
            { parent.Y },
            { parent.Z },
        }))

        -- cube root each individual value
        local _lms = matrix({ vim.tbl_map(utils.nroot, lms:transpose()[1]) }):transpose()

        -- transform to lab coordinates
        local lab = M.Oklab_to_XYZ_M2:mul(_lms):transpose()

        return self:new({
            L = lab[1][1],
            a = lab[1][2],
            b = lab[1][3],
        })
    end,
}
M.Oklab.__index = M.Oklab
setmetatable(M.Oklab, Color)

return M
