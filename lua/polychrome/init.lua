local colorscheme = require('polychrome.colorscheme')
local color = require('polychrome.color')

local M = {}

M.Colorscheme = colorscheme.Colorscheme
M.rgb = color.RGB
M.lrgb = color.lRGB
M.hsl = color.HSL
M.oklab = color.Oklab
M.oklch = color.Oklch

return M
