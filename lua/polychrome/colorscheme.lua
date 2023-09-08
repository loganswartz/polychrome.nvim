local color = require('polychrome.color')
local utils = require('polychrome.utils')

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
---@field has_combo_link fun(self: Group): boolean
---@field lookup_hl fun(self: Group, key: string): string|nil
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

    has_combo_link = function(self)
        -- check if
        local present_attrs = vim.tbl_map(function(attr) return rawget(self, attr) ~= nil end, { 'fg', 'bg', 'gui' })
        local has_another_attr = vim.tbl_contains(present_attrs, true)
        return self:get_link() ~= nil and has_another_attr
    end,

    ---@see docs :h nvim_set_hl
    to_definition_map = function(self)
        local map = {}

        local link = self:get_link()
        if link then
            if self:has_combo_link() then -- unroll the link and pass all the properties directly
                map.fg = self:lookup_hl('fg')
                map.bg = self:lookup_hl('bg')
                map.gui = self:lookup_hl('gui')
            else -- create a normal link
                map.link = type(link) == "string" and link or link.name
            end
        end

        for _, prop in ipairs({ 'fg', 'bg' }) do
            if self[prop] ~= nil then
                map[prop] = self[prop].is_color_object and self[prop]:hex() or self[prop]
            end
        end

        if self.gui ~= nil then
            map[self.gui] = true
        end

        return map
    end,
}

---@class Options
---@field inject_gui_groups boolean|nil  Should some default groups be automatically defined?

---@class Colorscheme
---@field name string
---@field groups { [string]: Group }
---@field new fun(self: Colorscheme, name: string): Colorscheme
---@field define fun(name: string, definition: fun(_: fun()), options: Options|nil): Colorscheme  Define a new colorscheme
---@field apply fun(self: Colorscheme)  Apply the created colorscheme
---@field extend fun(self: Colorscheme, func: fun(_: fun()))  Run the given function with a modified global environment to enable use of our DSL
---@field _register_group fun(self: Colorscheme, group_name: string): Group  Register a group to the colorscheme
---@field _inject_gui_features fun(self: Colorscheme)  Register some sensible default groups

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
    define = function(name, definition, options)
        if (name == nil) then
            error("You must give the colorscheme a name.")
        end

        local colorscheme = M.Colorscheme:new(name)

        -- register the typical GUI features
        local skip_inject_gui = options ~= nil and options.inject_gui_groups == false
        -- don't apply if explicitly disabled
        if not skip_inject_gui then
            colorscheme:_inject_gui_features()
        end
        -- register the user-specified highlights
        colorscheme:extend(definition)

        -- if the live preview mode is active, this allows it to access the
        -- colorscheme directly without any complicated logic
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

    extend = function(self, func)
        local register = utils.partial(self._register_group, self)

        -- this will serve as the global environment for the given function
        local lookup = setmetatable({
            -- inject color system constructors so we don't have to import them
            RGB = color.rgb,
            rgb = color.rgb,
            lRGB = color.lrgb,
            lrgb = color.lrgb,
            HSL = color.hsl,
            hsl = color.hsl,
            Oklab = color.oklab,
            oklab = color.oklab,
            Oklch = color.oklch,
            oklch = color.oklch,
            CIEXYZ = color.ciexyz,
            ciexyz = color.ciexyz,
            -- inject helper for group names that have special characters in them
            _ = register,
        }, {
            -- all other unrecognized global function calls should return
            -- existing groups from colorscheme.groups, or inject new ones
            __index = function(_, key)
                -- check _G first to allow using the standard globals
                return _G[key] or register(key)
            end,
        })

        -- with this, any call to an unrecognized global function will create a
        -- new highlight group under that name
        setfenv(func, lookup)

        -- run the function, which will update the colorscheme in-place
        return func(register)
    end,

    _register_group = function(self, group_name)
        local existing = self.groups[group_name]
        if existing then
            return existing
        end

        local group = M.Group:new(group_name)
        -- Allow the group to access the colorscheme context
        group.get_colorscheme = function()
            return self
        end
        -- register the group to the scheme
        rawset(self.groups, group_name, group)

        return group
    end,

    -- Register the basic GUI features to avoid boilerplate in user-defined colorschemes.
    -- Users can still overwriting these by simply specifying them themselves.
    _inject_gui_features = function(self)
        ---@diagnostic disable: undefined-global
        return self:extend(function()
            Strikethrough { gui = "strikethrough" }
            Underline { gui = "underline" }
            Underdouble { gui = "underdouble" }
            Undercurl { gui = "undercurl" }
            Underdotted { gui = "underdotted" }
            Underdashed { gui = "underdashed" }
            Reverse { gui = "reverse" }
            Standout { gui = "standout" }
            Bold { gui = "bold" }
            Italic { gui = "italic" }
        end)
    end,
}
M.Colorscheme.__index = M.Colorscheme

return M
