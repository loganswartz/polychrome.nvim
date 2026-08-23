---@see Reference https://drafts.csswg.org/css-color/#color-conversion-code
local M = {
    rgb = require("polychrome.color.rgb"),
    lrgb = require("polychrome.color.lrgb"),
    p3 = require("polychrome.color.p3"),
    linear_p3 = require("polychrome.color.linear_p3"),
    hsl = require("polychrome.color.hsl"),
    oklab = require("polychrome.color.oklab"),
    oklch = require("polychrome.color.oklch"),
    ciexyz = require("polychrome.color.ciexyz"),
    lms = require("polychrome.color.lms"),
}

return M
