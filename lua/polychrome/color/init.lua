---@see Reference https://drafts.csswg.org/css-color/#color-conversion-code
local M = {}

M.rgb = require('polychrome.color.rgb')
M.lrgb = require('polychrome.color.lrgb')
M.hsl = require('polychrome.color.hsl')
M.oklab = require('polychrome.color.oklab')
M.oklch = require('polychrome.color.oklch')
M.ciexyz = require('polychrome.color.ciexyz')

return M
