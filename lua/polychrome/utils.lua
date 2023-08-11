local M = {}

---@generic T
---@param self T
---@param obj table?
---@return T
function M.new(self, obj)
    obj = obj or {}
    setmetatable(obj, self)

    return obj
end

--- Convert a gamma-corrected RGB value to its linear RGB value.
---@param x number
---@return number
function M.gamma_to_linear(x)
    if x >= 0.04045 then
        return math.pow((x + 0.055) / 1.055, 2.4)
    else
        return x / 12.92
    end
end

--- Convert a linear RGB value to its gamma-corrected RGB value.
---@param x number
---@return number
function M.linear_to_gamma(x)
    if x > 0.0031308 then
        return 1.055 * math.pow(x, 1 / 2.4) - 0.055
    else
        return 12.92 * x
    end
end

--- Take the cube root of a number.
---@param n number
---@return number
function M.cuberoot(n)
    return math.pow(n, (1.0 / 3.0))
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

return M
