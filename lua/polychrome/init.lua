local colorscheme = require('polychrome.colorscheme')
local color = require('polychrome.color')
local commands = require('polychrome.commands')

local M = {
    Colorscheme = colorscheme.Colorscheme,
    rgb = color.rgb,
    lrgb = color.lrgb,
    hsl = color.hsl,
    oklab = color.oklab,
    oklch = color.oklch,
    ciexyz = color.ciexyz,
    lms = color.lms,
}

commands.setup()

return M
