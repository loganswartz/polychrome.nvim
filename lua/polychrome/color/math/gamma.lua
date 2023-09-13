local M = {}

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

return M
