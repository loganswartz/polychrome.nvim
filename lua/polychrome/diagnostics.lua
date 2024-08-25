local Set = require('polychrome.utils').Set

local M = {}

---@alias PositionKey string

---@class TSNodeRange
---@field row number
---@field col number
---@field end_row number|nil
---@field end_col number|nil
---@field byte number|nil
---@field end_byte number|nil

---@class ErrorBag
---@field type ErrorType
---@field message string
---@field group Group

--- A manager for diagnostics, that dedupes and applies diagnostics to the buffer
---
---@class DiagnosticManager
---@field _diagnostic_to_position_key fun(diagnostic: vim.Diagnostic): PositionKey
---@field _position_key_to_diagnostic fun(key: PositionKey, message: string, severity: vim.diagnostic.Severity|nil): vim.Diagnostic
---@field add fun(self: DiagnosticManager, diagnostics: vim.Diagnostic[])
---@field remove fun(self: DiagnosticManager, diagnostics: vim.Diagnostic[])
---@field clear fun(self: DiagnosticManager)
---@field apply fun(self: DiagnosticManager)
---@field get fun(self: DiagnosticManager): vim.Diagnostic[]
local DiagnosticManager = {
    new = function(self)
        local obj = {}

        setmetatable(obj, self)

        return obj
    end,

    _diagnostic_to_position_key = function(diagnostic)
        return ('%d:%d:%d:%d'):format(diagnostic.lnum, diagnostic.col, diagnostic.end_lnum, diagnostic.end_col)
    end,

    _position_key_to_diagnostic = function(key, message, severity)
        local function parse(value)
            if value == '' then
                return nil
            end
            return tonumber(value)
        end

        local lnum, col, end_lnum, end_col = key:match('(%d+):(%d+):(%d+):(%d+)')
        return {
            lnum = parse(lnum),
            col = parse(col),
            end_lnum = parse(end_lnum),
            end_col = parse(end_col),
            message = message,
            severity = severity or vim.diagnostic.severity.ERROR,
        }
    end,

    add = function(self, diagnostics)
        for _, diagnostic in ipairs(diagnostics) do
            local key = self._diagnostic_to_position_key(diagnostic)
            if not self[key] then
                self[key] = Set:new()
            end

            self[key]:add(diagnostic.message)
        end
    end,

    remove = function(self, diagnostics)
        for _, diagnostic in ipairs(diagnostics) do
            local key = self._diagnostic_to_position_key(diagnostic)

            if self[key] == nil then
                return
            end

            self[key]:remove(diagnostic.message)
        end

        self:apply()
    end,

    clear = function(self)
        for key in pairs(self) do
            self[key] = nil
        end
        self:apply()
    end,

    apply = vim.schedule_wrap(function(self, colorscheme)
        local diagnostics = self:get()

        if POLYCHROME_EDITING then
            vim.api.nvim_buf_clear_namespace(0, M.DIAGNOSTIC_NAMESPACE, 0, -1)
            vim.diagnostic.set(M.DIAGNOSTIC_NAMESPACE, 0, diagnostics)
        else
            for _, diagnostic in ipairs(diagnostics) do
                vim.notify('[' .. (colorscheme and colorscheme.name or 'polychrome') .. '] ' .. diagnostic.message,
                    vim.log.levels.ERROR)
            end
        end
    end),

    get = function(self)
        local diagnostics = {}

        for location, messages in pairs(self) do
            for _, message in ipairs(messages:tolist()) do
                local created = self._position_key_to_diagnostic(location, message)

                table.insert(diagnostics, created)
            end
        end

        return diagnostics
    end,

    __len = function(self)
        return #self:get()
    end,
}
DiagnosticManager.__index = DiagnosticManager

M.DIAGNOSTIC_NAMESPACE = vim.api.nvim_create_namespace('polychrome')
M.DIAGNOSTICS = DiagnosticManager:new()

---@param node TSNode
---@return TSNodeRange
local function to_range(node)
    local values = { node:range() }
    return {
        row = values[1],
        col = values[2],
        end_row = values[3],
        end_col = values[4],
        byte = values[5],
        end_byte = values[6],
    }
end

local function ts_find_table_value(value)
    local success, tree = pcall(vim.treesitter.get_parser, 0)
    if not success then
        return {}
    end

    local root = tree:parse()[1]:root()

    local query = vim.treesitter.query.parse('lua', ([[
        (field
          name: (identifier)
          value: (string
            content: (string_content) @value (#eq? @value "%s")))
    ]]):format(value))

    local found = {}
    for _, captures, _ in query:iter_matches(root, 0) do
        ---@type TSNode
        local value_node = captures[1]
        if value_node ~= nil then
            table.insert(found, to_range(value_node))
        end
    end

    return found
end

local function ts_find_table_key(group_name, value)
    local success, tree = pcall(vim.treesitter.get_parser, 0)
    if not success then
        return {}
    end

    local root = tree:parse()[1]:root()

    local query = vim.treesitter.query.parse('lua', ([[
        (function_call
          name: (identifier) @group (#eq? @group "%s")
          arguments: (arguments
            (table_constructor
              (field
                name: (identifier) @key (#eq? @key "%s")))))
    ]]):format(group_name, value))

    local found = {}
    for _, captures, _ in query:iter_matches(root, 0) do
        ---@type TSNode
        local value_node = captures[2]
        if value_node ~= nil then
            table.insert(found, to_range(value_node))
        end
    end

    return found
end

---@enum ErrorType
M.ERROR_TYPES = {
    INVALID_COLOR = 1,
    INVALID_ATTRIBUTE = 2,
}

---@type table<ErrorType, fun(error: ErrorBag): string>
M.ERROR_MESSAGES = {
    [M.ERROR_TYPES.INVALID_COLOR] = function(error)
        return ('Invalid color: \'%s\''):format(error.message:match('Invalid highlight color: \'(.*)\''))
    end,
    [M.ERROR_TYPES.INVALID_ATTRIBUTE] = function(error)
        return ('Invalid attribute name: %s'):format(error.message:match('Invalid attribute: \'(.*)\''))
    end,
}

---@type table<ErrorType, fun(error: ErrorBag): TSNodeRange[]>
M.REFINE_ERROR_LOCATION = {
    [M.ERROR_TYPES.INVALID_COLOR] = function(error)
        local _, _, bad_value = error.message:find('Invalid highlight color: \'(.*)\'')

        return ts_find_table_value(bad_value)
    end,
    [M.ERROR_TYPES.INVALID_ATTRIBUTE] = function(error)
        local _, _, bad_value = error.message:find('Invalid attribute: \'(.*)\'')

        return ts_find_table_key(error.group.name, bad_value)
    end,
}

---@type fun(error: ErrorBag): vim.Diagnostic[]
local function create_diagnostics_from_error(error)
    ---@type vim.Diagnostic[]
    local diagnostics = {}
    local ranges = M.REFINE_ERROR_LOCATION[error.type](error)

    -- use the original error location if we couldn't find a better one
    if #ranges == 0 then
        table.insert(ranges, {
            row = error.group._definition_locations[1].currentline or 0,
            col = 0,
        })
    end

    for _, location in ipairs(ranges) do
        table.insert(diagnostics, {
            message = M.ERROR_MESSAGES[error.type](error),
            severity = vim.diagnostic.severity.ERROR,
            lnum = location.row,
            col = location.col,
            end_lnum = location.end_row or location.row,
            end_col = location.end_col or location.col,
        })
    end

    return diagnostics
end

---@type fun(errors: ErrorBag[])
local function register_errors(errors)
    local diagnostics = {}
    for _, error in ipairs(errors) do
        local new = create_diagnostics_from_error(error)
        vim.list_extend(diagnostics, new)
    end

    M.DIAGNOSTICS:add(diagnostics)
end

---@type fun(errors: ErrorBag[])
M.add = vim.schedule_wrap(register_errors)

M.clear = function()
    M.DIAGNOSTICS:clear()
end

M.show = function(colorscheme)
    M.DIAGNOSTICS:apply(colorscheme)
end

return M
