local M = {}

local function load_buffer()
    local content = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
    return table.concat(content, "\n")
end

M.highlight_group = 'polychrome_edit_highlights'

local function get_highlight_groups()
    return (vim.api.nvim__get_hl_defs or vim.api.nvim_get_hl)(0)
end

---@param s string
local function escape(s)
    local matches =
    {
        ["^"] = "%^",
        ["$"] = "%$",
        ["("] = "%(",
        [")"] = "%)",
        ["%"] = "%%",
        ["."] = "%.",
        ["["] = "%[",
        ["]"] = "%]",
        ["*"] = "%*",
        ["+"] = "%+",
        ["-"] = "%-",
        ["?"] = "%?",
        ["\0"] = "%z",
    }
    return (s:gsub(".", matches))
end

local match_ids = {}

local function clear_highlights()
    vim.pretty_print(match_ids)
    for _, id in ipairs(match_ids) do
        vim.fn.matchdelete(id)
    end
end

local function apply_highlights()
    -- clear any previous matches
    clear_highlights()

    -- load current file
    POLYCHROME_EDITING = true
    local definition, result = load(load_buffer())
    if not definition then
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
        return
    end

    -- reapply the colorscheme
    ok = pcall(function() POLYCHROME_EDITING:apply() end)
    if not ok then
        return
    end

    -- highlight all defined highlight groups
    for name, _ in pairs(get_highlight_groups()) do
        local ok, match = pcall(vim.fn.matchadd, name, escape(name))
        if ok then
            table.insert(match_ids, match)
        end
    end
end

local editing_augroup = nil

function M.StartEditing()
    editing_augroup = vim.api.nvim_create_augroup('polychrome', { clear = true })
    vim.api.nvim_create_autocmd({
        'TextChanged',
        'TextChangedI',
        'TextChangedP',
        'TextChangedT',
    }, {
        group = editing_augroup,
        callback = apply_highlights,
    })
    apply_highlights()
end

function M.StopEditing()
    clear_highlights()
    vim.api.nvim_del_augroup_by_id(editing_augroup)
end

return M
