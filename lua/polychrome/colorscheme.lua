local state = require("polychrome.state")
local color = require("polychrome.color")
local diagnostics = require("polychrome.diagnostics")
local utils = require("polychrome.utils")
local make_config = require("polychrome.config").make_config
local Group = require("polychrome.group").Group
local GUI_HIGHLIGHTS = require("polychrome.group").GUI_HIGHLIGHTS
local osc = require("polychrome.osc")

local M = {}

---@class HealthChecker
---@field check fun(): nil The function that will run the health checks

---@class Colorscheme
---@field name string
---@field groups { [string]: Group }
---@field config PolychromeFullConfig
M.Colorscheme = {}
M.Colorscheme.__index = M.Colorscheme

---@param name string
---@param config PolychromeConfig?
---@return Colorscheme
function M.Colorscheme.new(name, config)
    local obj = {}
    obj.name = name
    obj.groups = {}
    obj.config = make_config(config)

    setmetatable(obj, M.Colorscheme)

    return obj
end

---Define a new colorscheme.
---@param name string
---@param definition fun(_: fun())
---@param config PolychromeConfig?
---@return Colorscheme
function M.Colorscheme.define(name, definition, config)
    assert(name, "You must give the colorscheme a name.")
    diagnostics.clear()

    local colorscheme = M.Colorscheme.new(name, config)

    -- register the typical GUI features if not explicitly disabled
    if not colorscheme.config.gui_groups.enable then
        colorscheme:_inject_gui_features()
    end

    -- register the user-specified highlights
    colorscheme:extend(definition)

    -- if the live preview mode is active, this allows it to access the
    -- colorscheme directly without any complicated logic
    if state.preview_is_active ~= nil then
        state.preview_colorscheme = colorscheme
    end

    return colorscheme
end

--- Apply the created colorscheme.
function M.Colorscheme:reload()
    vim.cmd.colorscheme(self.name)
end

---Patch the given group as needed for the configured autotransparency
---@param group Group
function M.Colorscheme:_patch_group_for_autotransparency(group)
    local transparent = self.config.autotransparency.groups[group.name]
    if not transparent then
        return
    end

    local match = self.groups[transparent.matches]
    if match == nil then
        return
    end

    local group_value = group.attributes[transparent.attribute]
    local target_value = match.attributes[transparent.attribute]

    if group_value == target_value then
        group.attributes[transparent.attribute] = "none"
    end
end

--- Apply the created colorscheme.
function M.Colorscheme:apply()
    if self.config.osc.enable then
        osc.setup(self.config)
        self:extend(state.osc_groups)
    end

    vim.cmd([[ highlight clear ]])
    vim.cmd([[ syntax on ]])

    vim.g.colors_name = self.name

    local errors = {}
    for name, group in pairs(self.groups) do
        local ok, result = pcall(function()
            if self.config.autotransparency.enable then
                self:_patch_group_for_autotransparency(group)
            end

            local hl = group:to_hl()

            vim.api.nvim_set_hl(0, name, hl)
        end)

        if state.preview_is_active and not ok then
            table.insert(errors, {
                type = diagnostics.ERROR_TYPES.INVALID_COLOR,
                message = result,
                group = group,
            })
        end
    end

    if state.preview_is_active then
        diagnostics.add(errors)
        diagnostics.show(self)
    end

    state.current_colorscheme = self
end

---Run the given function with a modified global environment to enable use of our DSL
---@param func_or_table Group[]|fun(_: fun())
function M.Colorscheme:extend(func_or_table)
    if type(func_or_table) == "table" then
        return self:_extend_with_table(func_or_table)
    else
        return self:_extend_with_func(func_or_table)
    end
end

---Extend the colorscheme with a prepopulated table of groups
---@param table Group[]|{[string]: Group}
function M.Colorscheme:_extend_with_table(table)
    local register = utils.partial(self._register_group, self)

    for _, group in pairs(table) do
        register(group)
    end
end

---Run the given function with a modified global environment to enable use of our DSL
---@param func fun(_: fun())
function M.Colorscheme:_extend_with_func(func)
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
end

---Apply the created colorscheme
---@param name string
---@return Colorscheme
function M.Colorscheme:clone_as(name)
    local clone = M.Colorscheme.new(name)
    clone.groups = vim.deepcopy(self.groups)

    return clone
end

---Register a group to the colorscheme
---@param group_or_name Group|string
---@return Group
function M.Colorscheme:_register_group(group_or_name)
    local group

    if type(group_or_name) == "string" then
        local name = group_or_name

        local existing = self.groups[name]
        if existing then
            return existing
        end

        group = Group.new(name)
    else
        group = group_or_name
    end

    -- register the group to the scheme
    rawset(self.groups, group.name, group)

    return group
end

---Register some sensible default groups.
---
---Register the basic GUI features to avoid boilerplate in user-defined colorschemes.
---Users can still overwriting these by simply specifying them themselves.
function M.Colorscheme:_inject_gui_features()
    ---@diagnostic disable: undefined-global
    return self:extend(function()
        -- register the GUI features
        for feature, hl_name in pairs(GUI_HIGHLIGHTS) do
            _(hl_name)({ [feature] = true })
        end
    end)
end

---Create a health checker for the colorscheme
---@return HealthChecker
function M.Colorscheme:health_checker()
    local function groups_where(filter)
        return vim.iter(self.groups):filter(filter):fold({}, function(acc, name, group)
            acc[name] = group
            return acc
        end)
    end

    local function no_empty_highlights_groups()
        local empty = groups_where(function(_, group)
            return vim.tbl_count(group:to_hl()) == 0
        end)

        if vim.tbl_count(empty) == 0 then
            vim.health.ok("All highlight groups have at least one attribute.")
            return
        end

        for name, _ in pairs(empty) do
            vim.health.warn("Highlight group '" .. name .. "' has no attributes.")
        end
    end

    local function all_groups_defined_exactly_once()
        local redefined = groups_where(function(_, group)
            return vim.tbl_count(group._definition_locations) > 1
        end)

        if vim.tbl_count(redefined) == 0 then
            vim.health.ok("All highlight groups were defined exactly once.")
            return
        end

        for name, group in pairs(redefined) do
            vim.health.warn(
                "Highlight group '"
                    .. name
                    .. "' was defined "
                    .. vim.tbl_count(group._definition_locations)
                    .. " times."
            )
        end
    end

    return {
        check = function()
            vim.health.start("Highlight groups")
            no_empty_highlights_groups()
            all_groups_defined_exactly_once()
        end,
    }
end

return M
