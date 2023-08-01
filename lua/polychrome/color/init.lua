---@see Reference https://drafts.csswg.org/css-color/#color-conversion-code
local M = {}

M.RGB = require('polychrome.color.rgb').RGB
M.lRGB = require('polychrome.color.lrgb').lRGB
M.HSL = require('polychrome.color.hsl').HSL
M.Oklab = require('polychrome.color.oklab').Oklab
M.Oklch = require('polychrome.color.oklch').Oklch

return M
