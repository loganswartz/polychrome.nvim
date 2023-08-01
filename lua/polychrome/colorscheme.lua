local color = require('polychrome.color')

local M = {}

---@class Group
---@field is_highlight_group true
---@field name string
---@field new fun(self: Group, name: string, obj: table?): Group
---@field __call fun(self: Group, attrs: table)
---@field check_link fun(self: Group): Group?|string
---@field to_definition_map fun(self: Group): table
---@field fg Color?
---@field bg Color?
---@field gui string?

---@type Group
M.Group = { ---@diagnostic disable-line: missing-fields
    is_highlight_group = true,

    new = function(self, name, obj)
        obj = obj or {}
        obj.name = name
        setmetatable(obj, self)

        return obj
    end,

    __call = function(table, attrs)
        for key, value in pairs(attrs) do
            rawset(table, key, value)
        end
    end,

    check_link = function(self)
        local link = self[1]
        if link == nil then
            return nil
        end

        if link.is_highlight_group then
            return link.name
        else -- the link is a raw string
            return link
        end
    end,

    -- TODO: fix stack overflows when using this in M.Group.__index
    get_link_value = function(self, key)
        local link = self:check_link()
        if not link then
            return nil
        end

        local ok, colors = pcall(vim.api.nvim_get_hl_by_name, link, true)
        if not ok or colors == nil or colors[key] == nil then
            return nil
        end

        return string.format("#%06x", colors[key])
    end,

    ---@see docs :h nvim_set_hl
    to_definition_map = function(self)
        local map = {}

        for _, prop in ipairs({ 'fg', 'bg' }) do
            if self[prop] ~= nil then
                map[prop] = self[prop].is_color_object and self[prop]:to_hex() or self[prop]
            end
        end

        if self.gui ~= nil then
            map[self.gui] = true
        end

        map.link = self:check_link()

        return map
    end,
}
M.Group.__index = M.Group

---@class Colorscheme
---@field name string
---@field groups { [string]: Group }
---@field new fun(self: Colorscheme, name: string): Colorscheme
---@field define fun(name: string, definition: fun(_: fun())): Colorscheme
---@field apply fun(self: Colorscheme)

---@type Colorscheme
M.Colorscheme = { ---@diagnostic disable-line: missing-fields
    new = function(self, name)
        local obj = {}
        obj.name = name
        obj.groups = {}
        setmetatable(obj, self)

        return obj
    end,

    -- Define a new colorscheme.
    define = function(name, definition)
        if (name == nil) then
            error("You must give the colorscheme a name.")
        end

        local colorscheme = M.Colorscheme:new(name)

        local function register_group(group_name)
            local existing = colorscheme.groups[group_name]
            if existing then
                return existing
            end

            local group = M.Group:new(group_name)
            rawset(colorscheme.groups, group_name, group)

            return group
        end

        local lookup = setmetatable({
            -- inject color system constructors so we don't have to import them
            RGB = color.RGB,
            rgb = color.RGB,
            lRGB = color.lRGB,
            lrgb = color.lRGB,
            HSL = color.HSL,
            hsl = color.HSL,
            Oklab = color.Oklab,
            oklab = color.Oklab,
            Oklch = color.Oklch,
            oklch = color.Oklch,
            -- inject helper for group names that have special characters in them
            _ = register_group,
        }, {
            -- all other unrecognized global function calls should return
            -- existing groups from colorscheme.groups, or inject new ones
            __index = function(_, key)
                -- check _G first to allow using the standard globals
                return _G[key] or register_group(key)
            end,
        })

        -- with this, any call to an unrecognized global function will create a
        -- new highlight group under that name
        setfenv(definition, lookup)

        -- run the user colorscheme definition, which will update the colorscheme in-place
        definition(register_group)

        return colorscheme
    end,

    -- Apply the created colorscheme.
    apply = function(self)
        vim.cmd [[ highlight clear ]]
        vim.cmd [[ syntax on ]]

        vim.g.colors_name = self.name

        for name, group in pairs(self.groups) do
            local ok, result = pcall(function()
                vim.api.nvim_set_hl(0, name, group:to_definition_map())
            end)

            if not ok then
                print('Error defining "' .. name .. '": ' .. result)
            end
        end
    end,
}
M.Colorscheme.__index = M.Colorscheme

return M
