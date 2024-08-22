local M = {}

--- Take the root of a number (default: cube root).
---@param number number
---@param root number|nil
---@return number
function M.nroot(number, root)
    -- any rooted negative number returns NaN, even if the root is a whole
    -- odd number. We can preserve the sign to restore the proper behavior.
    local sign = number >= 0 and 1 or -1
    return math.pow(math.abs(number), (1.0 / (root or 3.0))) * sign
end

--- Round a number to the nearest whole number.
---@param n number
---@return number
function M.round(n)
    return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end

--- Clamp a value to a specific range.
---@param value number
---@param bottom number?
---@param top number?
---@return number
function M.clamp(value, bottom, top)
    return math.max(math.min(value, top or 255), bottom or 0)
end

--- Adapted from https://github.com/runiq/neovim-throttle-debounce/blob/5247b097df15016ab31db672b77ec4938bb9cbfd/lua/throttle-debounce/init.lua#L3-L39
---
--- Throttles a function on the leading edge. Automatically `schedule_wrap()`s.
--- `timer:close()` at the end or you will leak memory!
---
---@generic F : function
---@param fn `F` Function to throttle
---@param ms number Timeout in ms
---@return (F, uv_timer_t|nil) throttled function and timer. Remember to call
function M.throttle(fn, ms)
    vim.validate({
        fn = { fn, "f" },
        ms = {
            ms,
            function(inner_ms)
                return type(inner_ms) == "number" and inner_ms > 0
            end,
            "number > 0",
        },
    })

    local timer = vim.loop.new_timer()
    local throttled = false

    local function wrapper(...)
        if throttled then
            return
        end

        throttled = true
        timer:start(ms, 0, function()
            throttled = false
        end)
        pcall(vim.schedule_wrap(fn), select(1, ...))
    end

    return wrapper, timer
end

--- Read the contents of the current buffer
function M.read_buffer(bufnr)
    local content = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
    return table.concat(content, "\n")
end

--- Escape a string to match literally in a vim regex
---@param s string
---@param prefix string|nil
function M.escape(s, prefix)
    prefix = prefix or "%"
    local special = { "^", "$", "(", ")", "%", ".", "[", "]", "*", "+", "-", "?" }

    -- generate a table like { char = prefix .. char }
    local mapped = vim.tbl_map(function(c) return { [c] = prefix .. c } end, special)
    local flattened = vim.tbl_flatten(mapped)

    return s:gsub(".", flattened)
end

function M.get_highlight_groups()
    if vim.api.nvim_get_hl ~= nil then
        return vim.api.nvim_get_hl(0, {})
    else
        return vim.api.nvim__get_hl_defs(0)
    end
end

---@param table table
---@param value any
---@param comparison (fun(a: any, b: any): boolean)|nil
---@return number|string|nil
function M.find(table, value, comparison)
    comparison = comparison or function(a, b) return a == b end

    for k, v in pairs(table) do
        if comparison(v, value) then
            return k
        end
    end

    return nil
end

function M.slice(list, start, _end, step)
    start = start ~= nil and start or 1
    _end = _end ~= nil and _end or #list
    step = step ~= nil and step or 1

    local new = {}
    for i = start, _end, step do
        table.insert(new, list[i])
    end

    return new
end

function M.reverse(list)
    local new = {}
    for i = #list, 1, -1 do
        table.insert(new, list[i])
    end

    return new
end

function M.partial(func, ...)
    local unpack = unpack or table.unpack
    local enclosed = { ... }

    return function(...)
        local passed = { ... }
        -- join the tables
        local params = { unpack(enclosed), unpack(passed) }
        return func(unpack(params))
    end
end

---@param x float
---@return float
function M.sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

---@class M.Set
---@field new fun(self: M.Set, ...: string[]): M.Set
---@field add fun(self: M.Set, ...: string[])
---@field remove fun(self: M.Set, ...: string[])
---@field has fun(self: M.Set, value: string): boolean
---@field tolist fun(self: M.Set): string[]
M.Set = {
    new = function(self, ...)
        local args = { ... }
        local obj = {}

        setmetatable(obj, self)

        obj:add(unpack(args))

        return obj
    end,

    add = function(self, ...)
        local args = { ... }
        for _, value in ipairs(args) do
            self[value] = true
        end
    end,

    remove = function(self, ...)
        local args = { ... }
        for _, value in ipairs(args) do
            self[value] = nil
        end
    end,

    has = function(self, value)
        return self[value] ~= nil
    end,

    tolist = function(self)
        return vim.tbl_keys(self)
    end,
}
M.Set.__index = M.Set

return M
