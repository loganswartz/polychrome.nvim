local utils = require('polychrome.utils')
local intersection = require('polychrome.color.lrgb.intersection')

local M = {}

---@param rgb lRGB
---@return boolean
local function in_lrgb_gamut(rgb)
    return rgb.lr < 1 and rgb.lg < 1 and rgb.lb < 1 and rgb.lr > 0 and rgb.lg > 0 and rgb.lb > 0
end

---@param rgb lRGB
---@return lRGB
function M.gamut_clip_preserve_chroma(rgb)
    -- if already in range, no changes needed
    if in_lrgb_gamut(rgb) then
        return rgb
    end

    local lab = rgb:to_parent()

    local L = lab.L
    local eps = 0.00001
    local C = math.max(eps, math.sqrt(lab.a * lab.a + lab.b * lab.b))
    local a_ = lab.a / C
    local b_ = lab.b / C

    local L0 = utils.clamp(L, 0, 1)

    local t = intersection.find_gamut_intersection(a_, b_, L, C, L0)
    local L_clipped = L0 * (1 - t) + t * L
    local C_clipped = t * C

    lab = require('polychrome.color.oklab').Oklab(L_clipped, C_clipped * a_, C_clipped * b_)
    return require('polychrome.color.lrgb').lRGB:_from_oklab_naive(lab)
end

---@param rgb lRGB
---@return lRGB
function M.gamut_clip_project_to_0_5(rgb)
    if in_lrgb_gamut(rgb) then
        return rgb
    end

    local lab = rgb:to_parent()

    local L = lab.L
    local eps = 0.00001
    local C = math.max(eps, math.sqrt(lab.a ^ 2 + lab.b ^ 2))
    local a_ = lab.a / C
    local b_ = lab.b / C

    local L0 = 0.5

    local t = intersection.find_gamut_intersection(a_, b_, L, C, L0)
    local L_clipped = L0 * (1 - t) + t * L
    local C_clipped = t * C

    lab = require('polychrome.color.oklab').Oklab(L_clipped, C_clipped * a_, C_clipped * b_)
    return require('polychrome.color.lrgb').lRGB:_from_oklab_naive(lab)
end

---@param rgb lRGB
---@return lRGB
function M.gamut_clip_project_to_L_cusp(rgb)
    if in_lrgb_gamut(rgb) then
        return rgb
    end

    local lab = rgb:to_parent()

    local L = lab.L
    local eps = 0.00001
    local C = math.max(eps, math.sqrt(lab.a ^ 2 + lab.b ^ 2))
    local a_ = lab.a / C
    local b_ = lab.b / C

    -- The cusp is computed here and in find_gamut_intersection, an optimized solution would only compute it once.
    local cusp = intersection.find_cusp(a_, b_)

    local L0 = cusp.L

    local t = intersection.find_gamut_intersection(a_, b_, L, C, L0)

    local L_clipped = L0 * (1 - t) + t * L
    local C_clipped = t * C

    lab = require('polychrome.color.oklab').Oklab(L_clipped, C_clipped * a_, C_clipped * b_)
    return require('polychrome.color.lrgb').lRGB:_from_oklab_naive(lab)
end

---@param rgb lRGB
---@param alpha number|nil
---@return lRGB
function M.gamut_clip_adaptive_L0_0_5(rgb, alpha)
    if in_lrgb_gamut(rgb) then
        return rgb
    end
    alpha = alpha or 0.05

    local lab = rgb:to_parent()

    local L = lab.L
    local eps = 0.00001
    local C = math.max(eps, math.sqrt(lab.a ^ 2 + lab.b ^ 2))
    local a_ = lab.a / C
    local b_ = lab.b / C

    local Ld = L - 0.5
    local e1 = 0.5 + math.abs(Ld) + alpha * C
    local L0 = 0.5 * (1 + utils.sign(Ld) * (e1 - math.sqrt(e1 * e1 - 2 * math.abs(Ld))))

    local t = intersection.find_gamut_intersection(a_, b_, L, C, L0)
    local L_clipped = L0 * (1 - t) + t * L
    local C_clipped = t * C

    lab = require('polychrome.color.oklab').Oklab(L_clipped, C_clipped * a_, C_clipped * b_)
    return require('polychrome.color.lrgb').lRGB:_from_oklab_naive(lab)
end

---@param rgb lRGB
---@param alpha number|nil
---@return lRGB
function M.gamut_clip_adaptive_L0_L_cusp(rgb, alpha)
    if in_lrgb_gamut(rgb) then
        return rgb
    end
    alpha = alpha or 0.05

    local lab = rgb:to_parent()

    local L = lab.L
    local eps = 0.00001
    local C = math.max(eps, math.sqrt(lab.a ^ 2 + lab.b ^ 2))
    local a_ = lab.a / C
    local b_ = lab.b / C

    -- The cusp is computed here and in find_gamut_intersection, an optimized solution would only compute it once.
    local cusp = intersection.find_cusp(a_, b_)

    local Ld = L - cusp.L
    local k = 2 * (Ld > 0 and 1 - cusp.L or cusp.L)

    local e1 = 0.5 * k + math.abs(Ld) + alpha * C / k
    local L0 = cusp.L + 0.5 * (utils.sign(Ld) * (e1 - math.sqrt(e1 * e1 - 2 * k * math.abs(Ld))))

    local t = intersection.find_gamut_intersection(a_, b_, L, C, L0)
    local L_clipped = L0 * (1 - t) + t * L
    local C_clipped = t * C

    lab = require('polychrome.color.oklab').Oklab(L_clipped, C_clipped * a_, C_clipped * b_)
    return require('polychrome.color.lrgb').lRGB:_from_oklab_naive(lab)
end

return M
