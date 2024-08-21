local color = require('polychrome.color')
local utils = require('polychrome.utils')
local Group = require('polychrome.group').Group
local GUI_FLAGS = require('polychrome.group').GUI_FLAGS

local M = {}

local DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace('polychrome')

local function ts_find_color_error_location(group_name, value)
    local tree = vim.treesitter.get_parser(0)
    if tree == nil then
        return nil
    end

    local root = tree:parse()[1]:root()

    local query = vim.treesitter.query.parse('lua', ([[
        (function_call
          name: (identifier) @groupname (#eq? @groupname "%s")
          arguments: (arguments
            (table_constructor
              (field
                name: (identifier)
                value: (string
                  content: (string_content) @colorvalue (#eq? @colorvalue "%s"))))))
    ]]):format(group_name, value))

    for _, captures, _ in query:iter_matches(root, 0) do
        ---@type TSNode
        local value_node = captures[2]
        local row, col, end_row, end_col = value_node:range()
        if row ~= nil then
            return { row, col, end_row, end_col }
        end
    end
end

local show_diagnostics_for = vim.schedule_wrap(function(errors)
    vim.api.nvim_buf_clear_namespace(0, DIAGNOSTIC_NAMESPACE, 0, -1)

    local diagnostics = {}
    for _, entry in ipairs(errors) do
        local _, _, bad_value = entry.error:find('Invalid highlight color: \'(.*)\'')
        local ts_location = ts_find_color_error_location(entry.group.name, bad_value)

        table.insert(diagnostics, {
            message = "Invalid color value: '" .. bad_value .. "'",
            severity = vim.diagnostic.severity.ERROR,
            lnum = ts_location and ts_location[1] or entry.group._definition_locations[1].currentline or 0,
            col = ts_location and ts_location[2] or 0,
            end_lnum = ts_location and ts_location[3] or nil,
            end_col = ts_location and ts_location[4] or nil,
        })
    end

    vim.diagnostic.set(DIAGNOSTIC_NAMESPACE, 0, diagnostics)
end)

---@class ColorschemeConfig
---@field inject_gui_groups boolean|nil Should some default groups be automatically defined?

---@class HealthChecker
---@field check fun(): nil The function that will run the health checks

---@class Colorscheme
---@field name string
---@field groups { [string]: Group }
---@field config ColorschemeConfig
---@field new fun(name: string, config: ColorschemeConfig|nil): Colorscheme
---@field define fun(name: string, definition: fun(_: fun()), config: ColorschemeConfig|nil): Colorscheme Define a new colorscheme
---@field apply fun(self: Colorscheme) Apply the created colorscheme
---@field clone_as fun(self: Colorscheme, name: string): Colorscheme Apply the created colorscheme
---@field extend fun(self: Colorscheme, func: fun(_: fun())) Run the given function with a modified global environment to enable use of our DSL
---@field _register_group fun(self: Colorscheme, group_name: string): Group Register a group to the colorscheme
---@field _inject_gui_features fun(self: Colorscheme) Register some sensible default groups
---@field health_checker fun(self: Colorscheme): HealthChecker Create a health checker for the colorscheme

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

        local errors = vim.iter({})
        for name, group in pairs(self.groups) do
            local ok, result = pcall(function()
                local hl = group:to_hl()

                vim.api.nvim_set_hl(0, name, hl)
            end)

            if not ok then
                table.insert(errors, { error = result, group = group })
            end
        end

        if POLYCHROME_EDITING then
            show_diagnostics_for(errors)
        else
            for name, error in pairs(errors:totable()) do
                vim.notify('[' .. self.name .. '] Error defining "' .. name .. '": ' .. error, vim.log.levels.ERROR)
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

        local group = Group.new(group_name)
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

    health_checker = function(self)
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
                vim.health.warn(
                    "Highlight group '" .. name .. "' has no attributes."
                )
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
                    "Highlight group '" ..
                    name .. "' was defined " .. vim.tbl_count(group._definition_locations) .. " times."
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
    end,
}
M.Colorscheme.__index = M.Colorscheme

return M
