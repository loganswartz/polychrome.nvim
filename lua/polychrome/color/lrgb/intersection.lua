local utils = require('polychrome.utils')

local M = {}

M.FLT_MAX = 2 ^ 1023.9999999999999

-- Finds the maximum saturation possible for a given hue that fits in sRGB
-- Saturation here is defined as S = C/L
-- a and b must be normalized so a^2 + b^2 == 1
---@param a float
---@param b float
---@return float
function M.compute_max_saturation(a, b)
    -- Max saturation will be when one of r, g or b goes below zero.

    -- Select different coefficients depending on which component goes below zero first
    local k0, k1, k2, k3, k4, wl, wm, ws

    if -1.88170328 * a - 0.80936493 * b > 1 then
        -- Red component
        k0 = 1.19086277; k1 = 1.76576728; k2 = 0.59662641; k3 = 0.75515197; k4 = 0.56771245
        wl = 4.0767416621; wm = -3.3077115913; ws = 0.2309699292
    elseif 1.81444104 * a - 1.19445276 * b > 1 then
        -- Green component
        k0 = 0.73956515; k1 = -0.45954404; k2 = 0.08285427; k3 = 0.12541070; k4 = 0.14503204
        wl = -1.2684380046; wm = 2.6097574011; ws = -0.3413193965
    else
        -- Blue component
        k0 = 1.35733652; k1 = -0.00915799; k2 = -1.15130210; k3 = -0.50559606; k4 = 0.00692167
        wl = -0.0041960863; wm = -0.7034186147; ws = 1.7076147010
    end

    -- Approximate max saturation using a polynomial:
    local S     = k0 + k1 * a + k2 * b + k3 * a * a + k4 * a * b

    -- Do one step Halley's method to get closer
    -- this gives an error less than 10e6, except for some blue hues where the dS/dh is close to infinite
    -- this should be sufficient for most applications, otherwise do two/three steps

    local k_l   = 0.3963377774 * a + 0.2158037573 * b
    local k_m   = -0.1055613458 * a - 0.0638541728 * b
    local k_s   = -0.0894841775 * a - 1.2914855480 * b

    local l_    = 1 + S * k_l
    local m_    = 1 + S * k_m
    local s_    = 1 + S * k_s

    local l     = l_ ^ 3
    local m     = m_ ^ 3
    local s     = s_ ^ 3

    local l_dS  = 3 * k_l * l_ ^ 2
    local m_dS  = 3 * k_m * m_ ^ 2
    local s_dS  = 3 * k_s * s_ ^ 2

    local l_dS2 = 6 * k_l ^ 2 * l_
    local m_dS2 = 6 * k_m ^ 2 * m_
    local s_dS2 = 6 * k_s ^ 2 * s_

    local f     = wl * l + wm * m + ws * s
    local f1    = wl * l_dS + wm * m_dS + ws * s_dS
    local f2    = wl * l_dS2 + wm * m_dS2 + ws * s_dS2

    S           = S - f * f1 / (f1 * f1 - 0.5 * f * f2)

    return S
end

---@class LC
---@field L float
---@field C float

-- finds L_cusp and C_cusp for a given hue
-- a and b must be normalized so a^2 + b^2 == 1

---@param a float
---@param b float
---@return LC
function M.find_cusp(a, b)
    -- First, find the maximum saturation (saturation S = C/L)
    local S_cusp = M.compute_max_saturation(a, b)

    -- Convert to linear sRGB to find the first point where at least one of r,g or b >= 1:
    local oklab = require('polychrome.color.oklab').Oklab(1, S_cusp * a, S_cusp * b)
    local rgb_at_max = require('polychrome.color.lrgb').lRGB:_from_oklab_naive(oklab)
    local L_cusp = utils.nroot(1 / math.max(math.max(rgb_at_max.lr, rgb_at_max.lg), rgb_at_max.lb))
    local C_cusp = L_cusp * S_cusp

    return { L = L_cusp, C = C_cusp }
end

-- Finds intersection of the line defined by
-- L = L0 * (1 - t) + t * L1
-- C = t * C1
-- a and b must be normalized so a^2 + b^2 == 1
---@param a float
---@param b float
---@param L1 float
---@param C1 float
---@param L0 float
---@param iterations number|nil
---@return float
function M.find_gamut_intersection(a, b, L1, C1, L0, iterations)
    -- Find the cusp of the gamut triangle
    local cusp = M.find_cusp(a, b)

    -- Find the intersection for upper and lower half seprately
    local t
    if (((L1 - L0) * cusp.C - (cusp.L - L0) * C1) <= 0) then
        -- Lower half

        t = cusp.C * L0 / (C1 * cusp.L + cusp.C * (L0 - L1))
    else
        -- Upper half

        -- First intersect with triangle
        t = cusp.C * (L0 - 1) / (C1 * (cusp.L - 1) + cusp.C * (L0 - L1))

        -- Then one step Halley's method
        local dL = L1 - L0
        local dC = C1

        local k_l = 0.3963377774 * a + 0.2158037573 * b
        local k_m = -0.1055613458 * a - 0.0638541728 * b
        local k_s = -0.0894841775 * a - 1.2914855480 * b

        local l_dt = dL + dC * k_l
        local m_dt = dL + dC * k_m
        local s_dt = dL + dC * k_s


        -- If higher accuracy is required, 2 or 3 iterations of the following block can be used:
        for _ = 0, iterations or 1 do
            local L = L0 * (1 - t) + t * L1
            local C = t * C1

            local l_ = L + C * k_l
            local m_ = L + C * k_m
            local s_ = L + C * k_s

            local l = l_ ^ 3
            local m = m_ ^ 3
            local s = s_ ^ 3

            local ldt = 3 * l_dt * l_ ^ 2
            local mdt = 3 * m_dt * m_ ^ 2
            local sdt = 3 * s_dt * s_ ^ 2

            local ldt2 = 6 * l_dt ^ 2 * l_
            local mdt2 = 6 * m_dt ^ 2 * m_
            local sdt2 = 6 * s_dt ^ 2 * s_

            local r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s - 1
            local r1 = 4.0767416621 * ldt - 3.3077115913 * mdt + 0.2309699292 * sdt
            local r2 = 4.0767416621 * ldt2 - 3.3077115913 * mdt2 + 0.2309699292 * sdt2

            local u_r = r1 / (r1 * r1 - 0.5 * r * r2)
            local t_r = -r * u_r

            local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s - 1
            local g1 = -1.2684380046 * ldt + 2.6097574011 * mdt - 0.3413193965 * sdt
            local g2 = -1.2684380046 * ldt2 + 2.6097574011 * mdt2 - 0.3413193965 * sdt2

            local u_g = g1 / (g1 * g1 - 0.5 * g * g2)
            local t_g = -g * u_g

            local b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s - 1
            local b1 = -0.0041960863 * ldt - 0.7034186147 * mdt + 1.7076147010 * sdt
            local b2 = -0.0041960863 * ldt2 - 0.7034186147 * mdt2 + 1.7076147010 * sdt2

            local u_b = b1 / (b1 * b1 - 0.5 * b * b2)
            local t_b = -b * u_b

            t_r = u_r >= 0 and t_r or M.FLT_MAX
            t_g = u_g >= 0 and t_g or M.FLT_MAX
            t_b = u_b >= 0 and t_b or M.FLT_MAX

            t = t + math.min(t_r, math.min(t_g, t_b))
        end
    end

    return t
end

return M
