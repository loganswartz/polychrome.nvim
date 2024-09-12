local utils = require('polychrome.utils')

local M = {}

--- Read the given template into the current buffer.
---
---@param filename string
M.read_into_current_buffer = function(filename)
    local root = utils.get_plugin_root()
    local template = vim.fs.joinpath(root, 'templates', filename)

    vim.cmd('silent keepalt read ' .. template)
    vim.cmd.normal('ggdd')
    vim.o.filetype = 'lua'
end

--- Create a function that reads the given template into the current buffer.
---
---@param filename string
M.read_into_current_buffer_factory = function(filename)
    return function()
        M.read_into_current_buffer(filename)
    end
end

return M
