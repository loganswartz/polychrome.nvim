local diagnostics = require "polychrome.diagnostics"
local M = {}

--- The options that hold the actual color values.
M.COLOR_OPTIONS = {
    'fg',
    'bg',
}

--- Options that can be set but will be translated to a different key / removed from the final object.
M.VIRTUAL_OPTIONS = {
    'gui',
}

--- A map of GUI flags to their corresponding highlight group keys.
M.GUI_FLAGS = {
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
M.GUI_OPTIONS = {
    'blend',
    'font',
}

--- The keys that are allowed to be set on a group definition.
M.ALLOWED_KEYS = vim.iter({ M.COLOR_OPTIONS, M.VIRTUAL_OPTIONS, M.GUI_OPTIONS, vim.tbl_keys(M.GUI_FLAGS) }):flatten()
    :totable()

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

---@class Group
---@field new fun(name: string, obj: table?): Group
---@field is_highlight_group boolean
---@field name string
---@field attributes GroupAttributes
---@field links Group[]
---@field _definition_locations debuginfo[]
---@field __call fun(self: Group, attrs: table)
---@field set fun(self: Group, key: string, value: any): Group Set the given attribute to the given value
---@field is_combo_link fun(self: Group): boolean Is a link present along with other attributes?
---@field _fold_links fun(self: Group): table Fold all the links into a single table
---@field is_pure_link fun(self: Group): boolean Is a single link present without any other attributes?
---@field from_hi fun(name: string): Group?  Create a new group definition from an existing highlight group fetched with `nvim_get_hl`
---@field to_hl fun(self: Group, resolve: boolean?): table Convert the group definition to a table suitable for `nvim_set_hl`

---@type Group
M.Group = { ---@diagnostic disable-line: missing-fields
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
        new._definition_locations = {}

        setmetatable(new, M.Group)

        -- if we're given an object, we'll use it to set the initial attributes
        if obj then
            new(obj)
        end

        return new
    end,

    is_highlight_group = true,

    __call = function(self, attrs)
        -- used in health checks to see if a group was defined multiple times
        table.insert(self._definition_locations, debug.getinfo(4))

        -- vim.iter.each walks both list and dict-like keys in tables
        vim.iter(pairs(attrs)):each(function(key, value)
            self:set(key, value)
        end)
    end,

    set = function(self, key, value)
        local is_valid_key = vim.tbl_contains(M.ALLOWED_KEYS, key) or type(key) == "number"

        local is_valid_bg_fg_value = vim.tbl_contains(M.COLOR_OPTIONS, key) and
            (value.is_color_object == true or type(value) == "string")
        local is_valid_gui_flag = vim.tbl_contains(vim.tbl_keys(M.GUI_FLAGS), key) and type(value) == "boolean"
        local is_valid_linked_group = type(key) == "number" and value.is_highlight_group == true
        local is_valid_gui_option = vim.tbl_contains(M.GUI_OPTIONS, key) and
            (type(value) == "number" or type(value) == "string")

        local is_valid_value = is_valid_bg_fg_value or is_valid_gui_flag or is_valid_linked_group or is_valid_gui_option

        if not is_valid_key then
            diagnostics.add({ {
                type = diagnostics.ERROR_TYPES.INVALID_ATTRIBUTE_KEY,
                message = "Invalid attribute key: '" .. key .. "'",
                group = self,
            } })
            goto finish
        end
        if not is_valid_value then
            diagnostics.add({ {
                type = diagnostics.ERROR_TYPES.INVALID_ATTRIBUTE_VALUE,
                message = "Invalid attribute value for: '" .. key .. "'",
                group = self,
            } })
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
        if vim.tbl_contains(M.COLOR_OPTIONS, key) and type(value) == "number" then
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

        return M.Group.new(name, group)
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
            local flags = vim.iter(M.GUI_FLAGS):map(function(flag)
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

return M
