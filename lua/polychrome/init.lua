local colorscheme = require('polychrome.colorscheme')
local color = require('polychrome.color')
local preview = require('polychrome.preview')

local M = {}

M.Colorscheme = colorscheme.Colorscheme
M.rgb = color.RGB
M.lrgb = color.lRGB
M.hsl = color.HSL
M.oklab = color.Oklab
M.oklch = color.Oklch
M.StartPreview = preview.StartPreview
M.StopPreview = preview.StopPreview

vim.api.nvim_create_user_command('StartPreview', function() preview.StartPreview() end, {})
vim.api.nvim_create_user_command('StopPreview', function() preview.StopPreview() end, {})

return M
