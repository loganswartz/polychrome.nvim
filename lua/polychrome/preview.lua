local utils = require('polychrome.utils')
local diagnostics = require('polychrome.diagnostics')

local M = {}

local PREVIEW_NAMESPACE = vim.api.nvim_create_namespace('polychrome_preview')
--- The ID of the augroup for our autocommands
local AUGROUP_ID = nil
---@type string|nil
local PREVIOUS_COLORSCHEME = nil

-- whitespace or quote mark directly before start of name
local _HL_NAME_LEADING_PATTERN = [=[[%s"']]=]
-- whitespace, period, open paren, or open curly brace directly after name
local _HL_NAME_TRAILING_PATTERN = [=[[%s"'%.%(%{]]=]
-- allowed characters in hl group names are `@`, `.`, `a-Z`, and `0-9`
local _HL_NAME_CAPTURE = [[([%w%d@%.]+)]]
local HL_NAME_REGEX = _HL_NAME_LEADING_PATTERN .. _HL_NAME_CAPTURE .. _HL_NAME_TRAILING_PATTERN

local COLOR_REGEX = [[(%w+)%(([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*%)]]

local function clear_highlights()
    pcall(vim.api.nvim_buf_clear_namespace, 0, PREVIEW_NAMESPACE, 0, -1)
end

local function apply_hl_group_name_hl(groups, line_nr, line)
    local start, _end, match = line:find(HL_NAME_REGEX)
    if match and groups[match] ~= nil then
        vim.api.nvim_buf_add_highlight(0, PREVIEW_NAMESPACE, match, line_nr - 1, start or 0, _end - 1 or -1)
    end
end

local function apply_color_obj_hl(groups, line_nr, line)
    local start, _end, name, a, b, c = line:find(COLOR_REGEX)

    if start ~= nil then
        name = string.lower(name)

        local class = require('polychrome.color')[name]
        if class.is_color_object then
            local color = class(tonumber(a), tonumber(b), tonumber(c))
            if not color then
                return
            end

            local hl_name = table.concat({ name, a, b, c }, '')

            vim.api.nvim_set_hl(0, hl_name, { fg = 'black', bg = color:hex() })
            vim.api.nvim_buf_add_highlight(0, PREVIEW_NAMESPACE, hl_name, line_nr - 1, start - 1, _end or -1)
        end
    end
end

--- Highlight all currently-defined highlight groups
local function apply_highlights()
    local groups = utils.get_highlight_groups()
    local lines = vim.api.nvim_buf_get_lines(0 or 0, 0, -1, false)

    for idx, line in ipairs(lines) do
        apply_hl_group_name_hl(groups, idx, line)
        apply_color_obj_hl(groups, idx, line)
    end
end

--- Extract a colorscheme from the current buffer.
local function apply_colorscheme()
    if vim.bo.filetype ~= 'lua' then
        vim.notify('[polychrome] Cannot live reload colorscheme because it is not a Lua file!')
    end

    -- clear any previous matches
    clear_highlights()

    -- load current file
    ---@type Colorscheme|true|nil
    POLYCHROME_EDITING = true
    local definition = load(utils.read_buffer(0))
    if not definition then
        return -- not runnable
    end

    -- run it
    local ok = pcall(definition)
    if not ok then
        return
    end

    -- check if a definition was run in the file
    if POLYCHROME_EDITING == nil or POLYCHROME_EDITING == true then
        vim.notify('[polychrome] Could not find a colorscheme through the current buffer!')
        return
    end

    -- reapply the colorscheme
    ok = pcall(function() POLYCHROME_EDITING:apply() end)
    if not ok then
        return
    end
end

local function apply_preview()
    pcall(function()
        apply_colorscheme()
        apply_highlights()
    end)
end

local function clear_preview()
    clear_highlights()
    diagnostics.clear()
    pcall(vim.api.nvim_del_augroup_by_id, AUGROUP_ID)
end

--- Activate a live preview of the colorscheme.
function M.StartPreview()
    PREVIOUS_COLORSCHEME = vim.g.colors_name

    -- start with a clean slate
    clear_preview()

    -- register the live preview
    AUGROUP_ID = vim.api.nvim_create_augroup('polychrome_preview', { clear = true })
    vim.api.nvim_create_autocmd({
        'TextChanged',
        'TextChangedI',
        'TextChangedP',
        'TextChangedT',
    }, {
        buffer = 0,
        group = AUGROUP_ID,
        callback = apply_preview,
    })

    -- immediately apply once
    apply_preview()
end

--- Deactivate the live preview of the colorscheme.
function M.StopPreview()
    clear_preview()

    if PREVIOUS_COLORSCHEME ~= nil then
        vim.cmd.colorscheme(PREVIOUS_COLORSCHEME)
        PREVIOUS_COLORSCHEME = nil
    end
end

return M
