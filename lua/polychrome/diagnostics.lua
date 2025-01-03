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
---@field _diagnostics vim.Diagnostic[]
---@field _diagnostics_are_equivalent fun(a: vim.Diagnostic, b: vim.Diagnostic): boolean
---@field add fun(self: DiagnosticManager, diagnostics: vim.Diagnostic[])
---@field remove fun(self: DiagnosticManager, diagnostics: vim.Diagnostic[])
---@field clear fun(self: DiagnosticManager)
---@field apply fun(self: DiagnosticManager)
---@field get fun(self: DiagnosticManager): vim.Diagnostic[]
local DiagnosticManager = {
    new = function(self)
        local obj = {}
        obj._diagnostics = {}

        setmetatable(obj, self)

        return obj
    end,

    _diagnostics_are_equivalent = function(a, b)
        for key, value in pairs(a) do
            if value ~= b[key] then
                return false
            end
        end

        return true
    end,

    has = function(self, diagnostic)
        for _, existing in ipairs(self._diagnostics) do
            if self._diagnostics_are_equivalent(diagnostic, existing) then
                return true
            end
        end

        return false
    end,

    add = function(self, diagnostics)
        for _, diagnostic in ipairs(diagnostics) do
            if not self:has(diagnostic) then
                table.insert(self._diagnostics, diagnostic)
            end
        end

        self:apply()
    end,

    remove = function(self, diagnostics)
        local to_keep = {}

        for _, diagnostic in ipairs(diagnostics) do
            for _, existing in ipairs(self._diagnostics) do
                if not self._diagnostics_are_equivalent(diagnostic, existing) then
                    table.insert(to_keep, existing)
                end
            end
        end

        self._diagnostics = to_keep
        self:apply()
    end,

    clear = function(self)
        self._diagnostics = {}
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
        return self._diagnostics
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

local function ts_find_table_string_value(value)
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

local function ts_find_table_value(group, key)
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
                name: (identifier) @key (#eq? @key "%s")
                value: (_) @value))))
    ]]):format(group, key))

    local found = {}
    for _, captures, _ in query:iter_matches(root, 0) do
        ---@type TSNode
        local value_node = captures[3]
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
        local value_node = captures[2][1]
        if value_node ~= nil then
            table.insert(found, to_range(value_node))
        end
    end

    return found
end

---@enum ErrorType
M.ERROR_TYPES = {
    INVALID_COLOR = 1,
    INVALID_ATTRIBUTE_KEY = 2,
    INVALID_ATTRIBUTE_VALUE = 3,
}

---@type table<ErrorType, vim.diagnostic.Severity>
M.ERROR_SEVERITIES = {
    [M.ERROR_TYPES.INVALID_COLOR] = vim.diagnostic.severity.WARN,
    [M.ERROR_TYPES.INVALID_ATTRIBUTE_KEY] = vim.diagnostic.severity.WARN,
    [M.ERROR_TYPES.INVALID_ATTRIBUTE_VALUE] = vim.diagnostic.severity.WARN,
}

---@type table<ErrorType, fun(error: ErrorBag): string>
M.ERROR_MESSAGES = {
    [M.ERROR_TYPES.INVALID_COLOR] = function(error)
        return ('Invalid color: \'%s\''):format(error.message:match('Invalid highlight color: \'(.*)\''))
    end,
    [M.ERROR_TYPES.INVALID_ATTRIBUTE_KEY] = function(error)
        return ('Invalid attribute name: %s'):format(error.message:match('Invalid attribute key: \'(.*)\''))
    end,
    [M.ERROR_TYPES.INVALID_ATTRIBUTE_VALUE] = function(error)
        return 'Invalid attribute value'
    end,
}

---@type table<ErrorType, fun(error: ErrorBag): TSNodeRange[]>
M.REFINE_ERROR_LOCATION = {
    [M.ERROR_TYPES.INVALID_COLOR] = function(error)
        local _, _, bad_value = error.message:find('Invalid highlight color: \'(.*)\'')

        return ts_find_table_string_value(bad_value)
    end,
    [M.ERROR_TYPES.INVALID_ATTRIBUTE_KEY] = function(error)
        local _, _, bad_value = error.message:find('Invalid attribute key: \'(.*)\'')

        return ts_find_table_key(error.group.name, bad_value)
    end,
    [M.ERROR_TYPES.INVALID_ATTRIBUTE_VALUE] = function(error)
        local _, _, key = error.message:find('Invalid attribute value for: \'(.*)\'')

        return ts_find_table_value(error.group.name, key)
    end,
}

---@type fun(error: ErrorBag): vim.Diagnostic[]
local function create_diagnostics_from_error(error)
    ---@type vim.Diagnostic[]
    local diagnostics = {}

    local refiner = M.REFINE_ERROR_LOCATION[error.type]
    local ranges = refiner and refiner(error) or {}

    -- use the original error location if we couldn't find a better one
    if #ranges == 0 then
        table.insert(ranges, {
            row = error.group and error.group._definition_locations[1].currentline or 0,
            col = 0,
        })
    end

    for _, location in ipairs(ranges) do
        ---@type vim.Diagnostic
        local new = {
            message = M.ERROR_MESSAGES[error.type](error),
            source = 'polychrome',
            namespace = M.DIAGNOSTIC_NAMESPACE,
            severity = M.ERROR_SEVERITIES[error.type],
            lnum = location.row,
            col = location.col,
            end_lnum = location.end_row or location.row,
            end_col = location.end_col or location.col,
        }
        table.insert(diagnostics, new)
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
