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

return M
