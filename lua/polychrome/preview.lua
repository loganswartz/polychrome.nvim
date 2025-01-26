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

local function apply_color_obj_hl(line_nr, line)
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
        apply_color_obj_hl(idx, line)
    end
end

--- Extract a colorscheme from the current buffer.
local function apply_colorscheme()
    -- clear any previous matches
    clear_highlights()

    -- load current file
    ---@type Colorscheme|true|nil
    POLYCHROME_EDITING = true
    local definition = load(utils.read_buffer(0))
    if not definition then
        return
    end

    -- valid lua, so set the filetype in case it's a template
    vim.bo.filetype = 'lua'

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
    pcall(function()
        -- Fire ColorScheme events.
        --
        -- Among other things, firing these events will usually allow plugins
        -- to reload their colors properly, so they will actually be able to
        -- live reload their colors as well.
        --
        -- According to `:help ColorScheme`, `<amatch>` should be the name of
        -- the colorscheme, so we have to pass it to `pattern` here. `<afile>`
        -- is supposed to be the current file when the `:colorscheme` command
        -- was run, but it appears that `vim.api.nvim_exec_autocmds` explicitly
        -- hardcodes null for that, so it appears they want to prevent
        -- non-internal calls from being able to set that value.
        --
        -- https://github.com/neovim/neovim/blob/b8e947ed4ed04f9aeef471f579451bbf2bb2993d/src/nvim/api/autocmd.c#L771
        vim.api.nvim_exec_autocmds('ColorSchemePre', { pattern = POLYCHROME_EDITING.name })

        -- apply the highlights
        POLYCHROME_EDITING:apply()

        vim.api.nvim_exec_autocmds('ColorScheme', { pattern = POLYCHROME_EDITING.name })
    end)
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
function M.start()
    -- start with a clean slate
    M.stop()

    PREVIOUS_COLORSCHEME = vim.g.colors_name

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
function M.stop()
    clear_preview()

    if PREVIOUS_COLORSCHEME ~= nil then
        vim.cmd.colorscheme(PREVIOUS_COLORSCHEME)
        PREVIOUS_COLORSCHEME = nil
    end
end

-- See |hitest.vim|
function M.show_hitest()
    vim.cmd [[ so $VIMRUNTIME/syntax/hitest.vim ]]
end

return M
