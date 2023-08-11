local utils = require('polychrome.utils')

local M = {}

local HL_NAMESPACE = nil
--- The ID of the augroup for our autocommands
local AUGROUP_ID = nil
--- Number of the buffer the live preview was activated on
local BUFNR = nil

-- whitespace or quote mark directly before start of name
local _LEADING_PATTERN = [=[[%s"']]=]
-- whitespace, period, open paren, or open curly brace directly after name
local _TRAILING_PATTERN = [=[[%s"'%.%(%{]]=]
-- allowed characters in hl group names are `@`, `.`, `a-Z`, and `0-9`
local _CAPTURE = [[([%w%d@%.]+)]]
local HL_NAME_REGEX = _LEADING_PATTERN .. _CAPTURE .. _TRAILING_PATTERN

local function clear_highlights()
    pcall(vim.api.nvim_buf_clear_namespace, BUFNR, HL_NAMESPACE, 0, -1)
end

--- Highlight all currently-defined highlight groups
local function apply_highlights()
    local groups = utils.get_highlight_groups()
    local lines = vim.api.nvim_buf_get_lines(BUFNR or 0, 0, -1, false)

    for idx, line in ipairs(lines) do
        local start, _end, match = line:find(HL_NAME_REGEX)
        if match and groups[match] ~= nil then
            vim.api.nvim_buf_add_highlight(BUFNR, HL_NAMESPACE, match, idx - 1, start or 0, _end - 1 or -1)
        end
    end
end

--- Extract a colorscheme from the current buffer.
local function apply_colorscheme()
    if vim.bo.filetype ~= 'lua' then
        print('[polychrome] Cannot live reload colorscheme because it is not a Lua file!')
    end

    -- clear any previous matches
    clear_highlights()

    -- load current file
    POLYCHROME_EDITING = true
    local definition, result = load(utils.read_buffer(BUFNR))
    if not definition then
        print(result)
        return -- not runnable
    end

    -- run it
    local ok, result = pcall(definition)
    if not ok then
        print(result)
        return
    end

    -- check if a definition was run in the file
    if POLYCHROME_EDITING == nil then
        print('[polychrome] Could not find a colorscheme through the current buffer!')
        return
    end

    -- reapply the colorscheme
    ok = pcall(function() POLYCHROME_EDITING:apply() end)
    if not ok then
        return
    end
end

local function apply_preview()
    apply_colorscheme()
    apply_highlights()
end

local function clear_preview()
    clear_highlights()
    pcall(vim.api.nvim_del_augroup_by_id, AUGROUP_ID)
end

--- Activate a live preview of the colorscheme.
---@param throttle_ms number|nil
function M.StartPreview(throttle_ms)
    -- start with a clean slate
    clear_preview()

    -- register the live preview
    BUFNR = vim.fn.bufnr()
    HL_NAMESPACE = vim.api.nvim_create_namespace('polychrome_preview')
    AUGROUP_ID = vim.api.nvim_create_augroup('polychrome', { clear = true })
    vim.api.nvim_create_autocmd({
        'TextChanged',
        'TextChangedI',
        'TextChangedP',
        'TextChangedT',
    }, {
        buffer = BUFNR,
        group = AUGROUP_ID,
        callback = apply_preview,
    })

    -- immediately apply once
    apply_preview()
end

--- Deactivate the live preview of the colorscheme.
function M.StopPreview()
    clear_preview()
end

return M
