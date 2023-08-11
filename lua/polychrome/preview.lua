local utils = require('polychrome.utils')

local M = {}

M.HIGHLIGHT_GROUP_NAME = 'polychrome_edit_highlights'

---@param name string
local function get_highlight_name_pattern(name)
    -- whitespace or quote mark directly before start of name
    local LEADING_PATTERN = [[\([[:space:]"']\)\@<=]]
    -- whitespace, period, open paren, or open curly brace directly after name
    local TRAILING_PATTERN = [[\([[:space:]"'\.\(\{]\)\@=]]

    if name:find('@') then
        -- exclude period from treesitter groups (ex. to avoid applying `@string` to the first half of `@string.delimiter`)
        TRAILING_PATTERN = [[\([[:space:]"'\(\{]\)\@=]]
    end

    return LEADING_PATTERN .. utils.escape(name, [[/]]) .. TRAILING_PATTERN
end

local function get_highlight_name_pattern_lua(name)
    -- whitespace or quote mark directly before start of name
    local LEADING_PATTERN = [=[[%s"']]=]
    -- whitespace, period, open paren, or open curly brace directly after name
    local TRAILING_PATTERN = [=[[%s"'%.%(%{]]=]

    if name:find('@') then
        -- exclude period from treesitter groups (ex. to avoid applying `@string` to the first half of `@string.delimiter`)
        TRAILING_PATTERN = [=[[%s"'%(%{]]=]
    end

    return LEADING_PATTERN .. utils.escape(name) .. TRAILING_PATTERN
end

local function get_highlight_groups()
    if vim.api.nvim_get_hl ~= nil then
        return vim.api.nvim_get_hl(0, {})
    else
        return vim.api.nvim__get_hl_defs(0)
    end
end

local MATCH_IDS = {}

local function clear_highlights()
    for _, id in ipairs(MATCH_IDS) do
        pcall(vim.fn.matchdelete, id)
    end
end

--- What window was the live preview activated on?
local EDITING_WIN_NUMBER = nil
--- What buffer was the live preview activated on?
local EDITING_BUF_NUMBER = nil

--- Highlight all currently-defined highlight groups
local function apply_highlights()
    local groups = get_highlight_groups()
    local buffer = utils.read_buffer(EDITING_BUF_NUMBER)

    for name, _ in pairs(groups) do
        -- only add a match if there's a result in the buffer
        if buffer:find(get_highlight_name_pattern_lua(name)) then
            local ok, match = pcall(
                vim.fn.matchadd,
                name,
                get_highlight_name_pattern(name),
                nil,
                -1,
                { window = EDITING_WIN_NUMBER }
            )
            if ok then
                table.insert(MATCH_IDS, match)
            end
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
    local definition, result = load(utils.read_buffer(EDITING_BUF_NUMBER))
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

local function start_preview()
    apply_colorscheme()
    apply_highlights()
end

local EDITING_AUGROUP_ID = nil
local THROTTLED_FUNC = nil
---@type uv_timer_t|nil
local THROTTLE_TIMER = nil

local function cleanup_timer()
    pcall(function() THROTTLE_TIMER:close() end)
    THROTTLE_TIMER = nil
    THROTTLED_FUNC = nil
end

--- Activate a live preview of the colorscheme.
---@param throttle_ms number|nil
function M.StartPreview(throttle_ms)
    -- start with a clean slate
    cleanup_timer()
    clear_highlights()

    -- throttle highlight updates for performance
    THROTTLED_FUNC, THROTTLE_TIMER = utils.throttle(start_preview, throttle_ms or 500)

    -- register the live preview
    EDITING_BUF_NUMBER = vim.fn.bufnr()
    EDITING_WIN_NUMBER = vim.fn.winnr()
    EDITING_AUGROUP_ID = vim.api.nvim_create_augroup('polychrome', { clear = true })
    vim.api.nvim_create_autocmd({
        'TextChanged',
        'TextChangedI',
        'TextChangedP',
        'TextChangedT',
    }, {
        buffer = EDITING_BUF_NUMBER,
        group = EDITING_AUGROUP_ID,
        callback = THROTTLED_FUNC,
    })

    -- immediately apply once
    start_preview()
end

--- Deactivate the live preview of the colorscheme.
function M.StopPreview()
    cleanup_timer()
    clear_highlights()

    pcall(vim.api.nvim_del_augroup_by_id, EDITING_AUGROUP_ID)
end

return M
