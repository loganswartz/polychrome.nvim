---@see Reference https://drafts.csswg.org/css-color/#color-conversion-code
local M = {
    rgb = require('polychrome.color.rgb'),
    lrgb = require('polychrome.color.lrgb'),
    hsl = require('polychrome.color.hsl'),
    oklab = require('polychrome.color.oklab'),
    oklch = require('polychrome.color.oklch'),
    ciexyz = require('polychrome.color.ciexyz'),
}

return M
