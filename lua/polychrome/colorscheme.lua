local color = require('polychrome.color')
local utils = require('polychrome.utils')

local M = {}

local HL_NAME_MAPPING = {
    fg = 'foreground',
    bg = 'background',
    gui = 'special',
}

--- The options that hold the actual color values.
local COLOR_OPTIONS = {
    'fg',
    'bg',
}

--- Options that can be set but will be translated to a different key / removed from the final object.
local VIRTUAL_OPTIONS = {
    'gui',
}

--- A map of GUI flags to their corresponding highlight group keys.
local GUI_FLAGS = {
    bold = 'Bold',
    standout = 'Standout',
    underline = 'Underline',
    undercurl = 'Undercurl',
    underdouble = 'Underdouble',
    underdotted = 'Underdotted',
    underdashed = 'Underdashed',
    strikethrough = 'Strikethrough',
    italic = 'Italic',
    reverse = 'Reverse',
    nocombine = 'Nocombine',
}

--- The remaining (non-boolean) GUI options that can be set on a highlight group.
local GUI_OPTIONS = {
    'blend',
    'font',
}

--- The keys that are allowed to be set on a group definition.
local ALLOWED_KEYS = vim.tbl_flatten({ COLOR_OPTIONS, VIRTUAL_OPTIONS, GUI_OPTIONS, vim.tbl_keys(GUI_FLAGS) })

--- Convert a raw color number (from `nvim_get_hl`) to a hex string.
---
---@param raw number
local function raw_color_to_hex(raw)
    return string.format("#%06x", raw)
end

---@class GroupAttributes
---@field fg Color|string|nil
---@field bg Color|string|nil
---@field blend number?
---@field font string?
---@field bold boolean?
---@field standout boolean?
---@field underline boolean?
---@field undercurl boolean?
---@field underdouble boolean?
---@field underdotted boolean?
---@field underdashed boolean?
---@field strikethrough boolean?
---@field italic boolean?
---@field reverse boolean?
---@field nocombine boolean?

---@class GroupDef
---@field new fun(name: string, obj: table?): GroupDef
---@field is_highlight_group boolean
---@field name string
---@field attributes GroupAttributes
---@field links GroupDef[]
---@field _was_defined boolean
---@field __call fun(self: GroupDef, attrs: table)
---@field set fun(self: GroupDef, key: string, value: any): GroupDef Set the given attribute to the given value
---@field is_combo_link fun(self: GroupDef): boolean Is a link present along with other attributes?
---@field _fold_links fun(self: GroupDef): table Fold all the links into a single table
---@field is_pure_link fun(self: GroupDef): boolean Is a single link present without any other attributes?
---@field from_hi fun(name: string): GroupDef?  Create a new group definition from an existing highlight group fetched with `nvim_get_hl`
---@field to_hl fun(self: GroupDef, resolve: boolean?): table Convert the group definition to a table suitable for `nvim_set_hl`

---@type GroupDef
M.GroupDef = { ---@diagnostic disable-line: missing-fields
    new = function(name, obj)
        -- We do this rather than the typical idiom of:
        --
        -- ```lua
        -- function new(obj)
        --     obj = obj or {}
        --     ...
        -- end
        -- ```
        --
        -- ...because then we can just reuse all the input parsing used in
        -- `__call` and `set`.
        local new = {}
        new.name = name
        new.attributes = {}
        new.links = {}
        new._was_defined = false

        setmetatable(new, M.GroupDef)

        -- if we're given an object, we'll use it to set the initial attributes
        if obj then
            new(obj)
        end

        return new
    end,

    is_highlight_group = true,

    __call = function(self, attrs)
        -- if this group was already defined, we'll warn the user
        if self._was_defined == true then
            vim.notify("[polychrome] Highlight group '" .. self.name .. "' was defined multiple times.",
                vim.log.levels.WARN)
        else
            self._was_defined = true
        end

        -- vim.iter.each walks both list and dict-like keys in tables
        vim.iter(pairs(attrs)):each(function(key, value)
            self:set(key, value)
        end)
    end,

    set = function(self, key, value)
        if not (vim.tbl_contains(ALLOWED_KEYS, key) or type(key) == "number") then
            vim.notify("[polychrome] Invalid attribute '" .. key .. "' for highlight group '" .. self.name .. "'.",
                vim.log.levels.WARN)
            goto finish
        end

        -- you can pass links by not specifying a key, and at the end we'll either:
        --   a) set it to the `link` key if it's the only key and no other attributes are set
        --   b) fold all the links into a single table if there are multiple
        if type(key) == "number" then
            table.insert(self.links, value)

            goto finish
        end

        -- passing a `gui` key with a comma-separated list of flags is
        -- allowed, but we parse it out to the actual separate keys
        if key == 'gui' then
            -- split the list
            local parts = vim.iter(vim.split(value, ','))

            -- sanity check to make sure we don't accidentally infinitely
            -- recurse if someone passes `gui = 'gui'`
            local flags = parts:filter(function(flag) return flag ~= 'gui' end)

            -- set each flag
            flags:each(function(flag)
                self:set(flag, true)
            end)

            -- avoid setting the `gui` key itself
            goto finish
        end

        -- convert raw color numbers to hex strings
        -- probably unnecessary? but may be useful for debugging
        if vim.tbl_contains(COLOR_OPTIONS, key) and type(value) == "number" then
            value = raw_color_to_hex(value)
        end

        rawset(self.attributes, key, value)

        ::finish::
        return self
    end,

    is_combo_link = function(self)
        local link_count = vim.tbl_count(self.links)
        local have_multiple_links = link_count > 1
        local has_attributes = vim.tbl_count(self.attributes) > 0

        return have_multiple_links or (link_count > 0 and has_attributes)
    end,

    is_pure_link = function(self)
        return vim.tbl_count(self.links) == 1 and vim.tbl_count(self.attributes) == 0
    end,

    from_hi = function(name)
        local group = vim.api.nvim_get_hl(0, { name = name })

        return M.GroupDef.new(name, group)
    end,

    _fold_links = function(self)
        -- if we have a combo link, we unroll all the links and combine them
        return vim.iter(ipairs(self.links)):map(function(_, link)
            -- When folding links, we always want to resolve them to their
            -- effective form. Consider this example:
            --
            -- ```lua
            -- LspError { Error }
            -- LspDiagnosticError { LspError }
            -- LspUnderlinedDiagnosticError { LspDiagnosticError, Underlined }
            -- ```
            --
            -- If we were to naively fold the links for `LspUnderlinedError`,
            -- we'd get:
            --
            -- ```lua
            -- LspError { Error }
            -- -- because it's a pure link, evaluates to: { link = 'Error' }
            --
            -- Underline { underline = true }
            -- -- evaluates to: { underline = true }
            --
            -- LspUnderlinedError { LspError, Underlined }
            -- -- when folded, evaluates to: { link = 'LspError', underline = true }
            -- ```
            --
            -- So, any nested pure links end up contaminating the final folded
            -- result, since (Neo)vim ignores any other properties if a `link`
            -- is present. Hence, we resolve any nested links if the this is
            -- not a pure link itself.
            return link:to_hl(true)
        end):fold({}, function(acc, hl)
            return vim.tbl_extend('force', acc, hl)
        end)
    end,

    ---@param resolve boolean|nil Should we resolve/unroll nested links?
    to_hl = function(self, resolve)
        -- If we only have a single link and no other attributes, we want to
        -- use Neovim's built-in `link` key. We want to avoid using `link`
        -- in any other cases because when `link` is present, (Neo)vim will
        -- ignore any other properties we've passed in.
        --
        -- Getting rid of this special case at the beginning makes it so that
        -- if we progress past this point, we're dealing with a combo link or
        -- no link at all, and can just fold them all together without
        -- restraint (because no links will fold down into an empty table).
        if not resolve and self:is_pure_link() then
            return { link = self.links[1].name }
        end

        local base = self:_fold_links()
        local attrs = vim.iter(pairs(self.attributes))

        -- transform the attributes table into a table suitable for `nvim_set_hl`
        local mapped = attrs:fold(base, function(acc, key, value)
            if type(value) == "table" then
                if value.is_color_object then
                    -- convert color objects to sRGB hex strings
                    value = value:hex()
                elseif value.is_highlight_group then
                    -- for groups, we'll just use the name
                    value = value.name
                end
            end
            acc[key] = value

            return acc
        end)

        return mapped
    end,

    __index = function(self, key)
        -- if we're looking for the `gui` key, we'll return a comma-separated
        -- list of all the GUI flags that are set
        if key == 'gui' then
            local flags = vim.iter(GUI_FLAGS):map(function(flag)
                return self.attributes[flag] and flag or nil
            end):filter(function(flag)
                return flag ~= nil
            end)

            return flags:join(',')
        end

        -- check this table directly
        local on_this = rawget(self, key)
        if on_this ~= nil then
            return on_this
        end

        -- then check the attributes table
        local attributes = rawget(self, 'attributes')
        if attributes ~= nil and attributes[key] ~= nil then
            return attributes[key]
        end

        -- then check the metatable
        local metatable = getmetatable(self)
        if metatable ~= nil and metatable[key] ~= nil then
            return metatable[key]
        end

        -- then check all the links in order
        for _, link in ipairs(self.links) do
            local value = link[key]
            if value ~= nil then
                return value
            end
        end

        return nil
    end,
}

---@class ColorschemeConfig
---@field inject_gui_groups boolean|nil Should some default groups be automatically defined?

---@class Colorscheme
---@field name string
---@field groups { [string]: GroupDef }
---@field config ColorschemeConfig
---@field new fun(name: string, config: ColorschemeConfig|nil): Colorscheme
---@field define fun(name: string, definition: fun(_: fun()), config: ColorschemeConfig|nil): Colorscheme Define a new colorscheme
---@field apply fun(self: Colorscheme) Apply the created colorscheme
---@field clone_as fun(self: Colorscheme, name: string): Colorscheme Apply the created colorscheme
---@field extend fun(self: Colorscheme, func: fun(_: fun())) Run the given function with a modified global environment to enable use of our DSL
---@field _register_group fun(self: Colorscheme, group_name: string): GroupDef Register a group to the colorscheme
---@field _inject_gui_features fun(self: Colorscheme) Register some sensible default groups

---@type Colorscheme
M.Colorscheme = { ---@diagnostic disable-line: missing-fields
    new = function(name, config)
        local obj = {}
        obj.name = name
        obj.groups = {}
        obj.config = config or {}

        setmetatable(obj, M.Colorscheme)

        return obj
    end,

    -- Define a new colorscheme.
    define = function(name, definition, config)
        if (name == nil) then
            error("You must give the colorscheme a name.")
        end

        local colorscheme = M.Colorscheme.new(name, config)

        -- register the typical GUI features
        local skip_inject_gui = colorscheme.config.inject_gui_groups == false
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
                local hl = group:to_hl()
                self._check_notify_empty_group(hl, name)

                vim.api.nvim_set_hl(0, name, hl)
            end)

            if not ok then
                vim.notify('[polychrome] Error defining "' .. name .. '": ' .. result, vim.log.levels.ERROR)
            end
        end
    end,

    _check_notify_empty_group = function(hl, name)
        local empty = vim.tbl_count(hl) == 0

        if empty then
            vim.notify(
                "[polychrome] Highlight group '" ..
                name ..
                "' has no attributes. Likely, this means some group is linked to '" ..
                name .. "', but '" .. name .. "' was never defined.",
                vim.log.levels.INFO
            )
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
            LMS = color.lms,
            lms = color.lms,
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

    clone_as = function(self, name)
        local clone = M.Colorscheme.new(name)
        clone.groups = vim.deepcopy(self.groups)

        return clone
    end,

    _register_group = function(self, group_name)
        local existing = self.groups[group_name]
        if existing then
            return existing
        end

        local group = M.GroupDef.new(group_name)
        -- register the group to the scheme
        rawset(self.groups, group_name, group)

        return group
    end,

    -- Register the basic GUI features to avoid boilerplate in user-defined colorschemes.
    -- Users can still overwriting these by simply specifying them themselves.
    _inject_gui_features = function(self)
        ---@diagnostic disable: undefined-global
        return self:extend(function()
            -- register the GUI features
            for feature, hl_name in pairs(GUI_FLAGS) do
                _(hl_name) { [feature] = true }
            end
        end)
    end,
}
M.Colorscheme.__index = M.Colorscheme

return M
