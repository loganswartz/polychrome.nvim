local color = require('polychrome.color')

local M = {}

local HL_NAME_MAPPING = {
    fg = 'foreground',
    bg = 'background',
    gui = 'special',
}

local function get_hl_attr(hl, attr)
    local ok, colors = pcall(vim.api.nvim_get_hl_by_name, hl, true)
    local mapped_key = HL_NAME_MAPPING[attr] or attr
    if not ok or colors == nil or colors[mapped_key] == nil then
        return nil
    end

    return string.format("#%06x", colors[mapped_key])
end

---@class Group
---@field is_highlight_group true
---@field name string
---@field get_colorscheme fun(): Colorscheme?
---@field new fun(self: Group, name: string, obj: table?): Group
---@field __call fun(self: Group, attrs: table)
---@field get_link fun(self: Group): Group|string|nil
---@field to_definition_map fun(self: Group): table
---@field fg Color?
---@field bg Color?
---@field gui string?

---@type Group
M.Group = { ---@diagnostic disable-line: missing-fields
    is_highlight_group = true,
    get_colorscheme = function()
        return nil
    end,

    new = function(self, name, obj)
        obj = obj or {}
        obj.name = name
        setmetatable(obj, self)

        return obj
    end,

    __call = function(table, attrs)
        if vim.tbl_count(attrs) == 0 then
            print("Warning: Highlight group '" .. table.name .. "' has an empty attribute table.")
        end

        for key, value in pairs(attrs) do
            rawset(table, key, value)
        end
    end,

    __index = function(self, key)
        -- check link for attributes if present
        if HL_NAME_MAPPING[key] ~= nil then
            local link = getmetatable(self).get_link(self)
            if link then
                return link[key]
            end
        end

        return getmetatable(self)[key]
    end,

    get_link = function(self)
        return self[1]
    end,

    lookup_hl = function(self, key)
        return get_hl_attr(self:get_link(), key)
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

        local link = self:get_link()
        if link then
            map.link = type(link) == "string" and link or link.name
        end

        return map
    end,
}

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
            -- Allow the group to access the colorscheme context
            group.get_colorscheme = function()
                return colorscheme
            end
            -- register the group to the scheme
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

        if POLYCHROME_EDITING ~= nil then
            POLYCHROME_EDITING = colorscheme
        end

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
