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
---@param places number?
---@return number
function M.round(n, places)
    places = places or 0
    local scale = 10 ^ places

    return math.floor((n + 0.5) * scale) / scale
end

---@param a number
---@param b number
---@param epsilon number?
function M.roughly_equal(a, b, epsilon)
    epsilon = epsilon or 1e-4
    return math.abs(a - b) <= epsilon
end

---Convert Cartesian coordinates to polar coordinates
---@param first number|table The lightness value, or a table of values
---@param ... number
---@return number, number, number
function M.cartesian_to_polar(first, ...)
    local args = first
    local rest = { ... }
    if type(args) == "number" then
        args = vim.iter({ { first }, rest }):flatten():totable()
    end

    local L = args[1]
    local a = args[2]
    local b = args[3]
    local epsilon = 1e-8

    local c = math.sqrt((a ^ 2) + (b ^ 2))
    local _h = ((math.atan2(b, a) * 180 / math.pi) + 360) % 360
    local h = c < epsilon and 0 or _h

    return L, c, h
end

---Convert polar coordinates to Cartesian coordinates
---@param first number|table The lightness value, or a table of values
---@param ... number
---@return number, number, number
function M.polar_to_cartesian(first, ...)
    local args = first
    local rest = { ... }
    if type(args) == "number" then
        args = vim.iter({ { first }, rest }):flatten():totable()
    end

    local L = args[1]
    local c = args[2]
    local h = args[3]

    local radius = h * math.pi / 180
    local a = c * math.cos(radius)
    local b = c * math.sin(radius)

    return L, a, b
end

---Calculate the distance between two Cartesian coordinates.
---
---If scales is not supplied, then it assumes all axes are the same scale. If
---scales is supplied, the distance calculation is performed with those axes
---scaled proportionally.
---
---This is often useful to calculate if two points are sufficiently close to
---one another, i.e. does one sit within a circle/sphere/hypersphere of a
---certain radius, centered on the other point.
---@param a number[]
---@param b number[]
---@param scales number[]?
---@return number
function M.cartesian_distance(a, b, scales)
    assert(#a == #b and (scales == nil or #a == #scales), "Coordinates must be of the same dimension")

    local sum = 0

    for idx, _ in ipairs(a) do
        local scale = scales ~= nil and scales[idx] or 1
        local distance = (b[idx] - a[idx]) / scale

        sum = sum + (distance ^ 2)
    end

    return math.sqrt(sum)
end

---Calculate the distance between two polar coordinates
---@param a number[]
---@param b number[]
---@return number
function M.polar_distance(a, b)
    return M.cartesian_distance({ M.polar_to_cartesian(a) }, { M.polar_to_cartesian(b) })
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
---
---@generic F : function
---@param ms number Timeout in ms
---@param fn `F` Function to throttle
---@return F The throttled function
function M.throttle(ms, fn)
    vim.validate({
        fn = { fn, "function" },
        ms = {
            ms,
            function(inner_ms)
                return type(inner_ms) == "number" and inner_ms > 0
            end,
            "number > 0",
        },
    })

    local timer
    local throttled = false

    local function wrapper(...)
        if throttled then
            return
        end

        if timer == nil then
            timer = assert(vim.loop.new_timer(), "Failed to create timer")
        end

        throttled = true
        timer:start(ms, 0, function()
            throttled = false

            timer:close()
            timer = nil
        end)

        pcall(vim.schedule_wrap(fn), select(1, ...))
    end

    return wrapper
end

---@generic A
---@param ms number Timeout in ms
---@param fn fun(...: `A`): any Function to debounce
---@return fun(...: A): nil The debounced function
function M.debounce(ms, fn)
    vim.validate({
        fn = { fn, "function" },
        ms = {
            ms,
            function(inner_ms)
                return type(inner_ms) == "number" and inner_ms > 0
            end,
            "number > 0",
        },
    })

    local timer

    local function wrapper(...)
        local args = { ... }

        if timer then
            timer:stop()
        end

        timer = vim.defer_fn(function()
            pcall(fn, select(1, args))
        end, ms)
    end

    return wrapper
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
    local mapped = vim.tbl_map(function(c)
        return { [c] = prefix .. c }
    end, special)
    local flattened = vim.iter(mapped):flatten():totable()

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
    comparison = comparison or function(a, b)
        return a == b
    end

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

---@param x number
---@return number
function M.sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

function M.get_plugin_root()
    -- Tests in busted do not have the same lua PATHs as running normally in Neovim
    -- This means some PATH magic (module autodiscovery) doesn't work normally
    -- When testing, we manually inject the plugin root instead
    if M.PLUGIN_ROOT then
        return M.PLUGIN_ROOT
    end

    local root = debug.getinfo(2, "S").source:sub(2)
    return root:match("(.*/)")
end

function M.isNaN(x)
    return x ~= x
end

---@param checking table The table to check
---@param meta table The metatable to look for
---@return boolean Does the checked table inherit from the metatable?
function M.has_metatable(checking, meta)
    while checking ~= nil do
        checking = getmetatable(checking)
        if checking == meta then
            return true
        end
    end

    return false
end

---@class FindSubmodulesOpts
---@field exclude string[]?

---Dynamically find all submodules in the given path
---@param path string
---@param opts FindSubmodulesOpts
---@return table
function M.find_submodules(path, opts)
    opts = opts or {}
    opts.exclude = opts.exclude or {}
    table.insert(opts.exclude, "init")

    local parent_path = string.gsub(path, "%.", "/")
    local found = {}

    local rtp = vim.opt.rtp:get()
    -- Allow autodiscovery to work in tests
    table.insert(rtp, M.get_plugin_root())

    for _, dir in ipairs(rtp) do
        local raw_path = vim.fs.joinpath(dir, "/lua/", parent_path)

        for name, _ in vim.fs.dir(raw_path) do
            local module = name:gsub("%.lua$", "")

            if not vim.tbl_contains(opts.exclude, module) then
                table.insert(found, module)
            end
        end
    end

    return vim.iter(found):unique():totable()
end

---Dynamically import all submodules in the given path
---@param path string
---@param opts FindSubmodulesOpts
---@return table
function M.load_submodules(path, opts)
    local submodules = M.find_submodules(path, opts)

    return vim.iter(submodules):fold({}, function(t, v)
        local ok, mod = pcall(require, path .. "." .. v)
        if ok then
            t[v] = mod
        end
        return t
    end)
end

---Do not use.
---
---Monkeypatch some things so that PATH magic in tests works as expected.
function M._setup_for_tests()
    M.PLUGIN_ROOT = require("lfs").currentdir()
end

return M
