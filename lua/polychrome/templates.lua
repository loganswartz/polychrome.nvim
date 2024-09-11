local utils = require('polychrome.utils')

local M = {}

M.load_theme_template = function()
    local root = utils.get_plugin_root()
    local template = vim.fs.joinpath(root, 'templates', 'theme.lua.template')

    vim.cmd('silent keepalt read ' .. template)
    vim.cmd.normal('ggdd')
    vim.o.filetype = 'lua'
end

return M
