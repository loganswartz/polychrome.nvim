local preview = require('polychrome.preview')
local templates = require('polychrome.templates')

local M = {}

---@class Command
---@field _default string
---@field new fun(subcommands: table<string, any>, default: string|nil): Command
---@field make_handler fun(self: Command): fun(args: table)
---@field make_complete_handler fun(self: Command): fun(arg_lead: string, cmd_line: string, cursor_pos: number): table
local Command = {}

---@generic K
---@param subcommands table<K|'_default', any>
---@param default K|nil
Command.new = function(subcommands, default)
    local o = subcommands
    o._default = default

    setmetatable(o, Command)
    return o
end

Command.__call = function(self, sub, ...)
    if sub == nil and self._default == nil then
        print('You must specify a subcommand! (valid subcommands: ' .. table.concat(vim.tbl_keys(self), ', ') .. ')')
        return
    end

    local func = self[sub]

    if func == nil then
        print('Unknown subcommand: ' .. sub)
        return
    end

    return func(...)
end

Command.make_handler = function(self)
    ---@param args table
    return function(args)
        self((unpack or table.unpack)(args.fargs))
    end
end

Command.make_complete_handler = function(self)
    return function(arg_lead, cmd_line, cursor_pos)
        local before_arg_lead = string.gsub(cmd_line, arg_lead, '')
        local args = vim.split(before_arg_lead, ' ', { trimempty = true })
        -- drop the first (root) arg
        args = vim.list_slice(args, 2)

        ---@type table
        local cmd = self
        -- step through each level of subcommands
        for _, v in ipairs(args) do
            -- get the next subcommand
            local sub = cmd[v]

            -- we are at the bottom, no more subcommands
            if getmetatable(sub) ~= Command then
                -- nothing left to suggest
                cmd = {}
                break
            end

            cmd = sub
        end

        local subcommands = vim.tbl_filter(function(v) return v ~= '_default' end, vim.tbl_keys(cmd))
        table.sort(subcommands)

        return subcommands
    end
end

Command.__index = function(self, key)
    if key == nil then
        return self[self._default]
    end

    return Command[key]
end

local COMMANDS = Command.new({
    preview = Command.new({
        start = preview.start,
        stop = preview.stop,
    }, 'start'),
    template = Command.new({
        theme = templates.read_into_current_buffer_factory('theme.lua.template'),
    }),
})

local commands_loaded = false

M.setup = function()
    if commands_loaded then
        return
    end

    vim.api.nvim_create_user_command('Polychrome', COMMANDS:make_handler(),
        { nargs = '+', complete = COMMANDS:make_complete_handler() })

    -- deprecated commands
    vim.api.nvim_create_user_command('StartPreview', function()
        vim.deprecate(":StartPreview", ":Polychrome preview or :Polychrome preview start", "future versions",
            "polychrome.nvim",
            false)
        preview.start()
    end, {})
    vim.api.nvim_create_user_command('StopPreview', function()
        vim.deprecate(":StopPreview", ":Polychrome preview stop", "future versions", "polychrome.nvim", false)
        preview.stop()
    end, {})

    commands_loaded = true
end

return M
