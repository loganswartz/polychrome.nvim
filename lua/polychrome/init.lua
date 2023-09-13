local colorscheme = require('polychrome.colorscheme')
local color = require('polychrome.color')
local preview = require('polychrome.preview')

local M = {
    Colorscheme = colorscheme.Colorscheme,
    rgb = color.rgb,
    lrgb = color.lrgb,
    hsl = color.hsl,
    oklab = color.oklab,
    oklch = color.oklch,
    ciexyz = color.ciexyz,
    StartPreview = preview.StartPreview,
    StopPreview = preview.StopPreview,
}

vim.api.nvim_create_user_command('StartPreview', function() preview.StartPreview() end, {})
vim.api.nvim_create_user_command('StopPreview', function() preview.StopPreview() end, {})

return M
