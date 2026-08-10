local state = require("polychrome.state")
local Group = require("polychrome.group").Group
local Color = require("polychrome.color.base")

local M = {}

---@enum OscCode
M.OSC_CODES = {
    PALETTE = 4,
    SPECIAL = 5,
    FOREGROUND = 10,
    BACKGROUND = 11,
    CURSOR = 12,
    HIGHLIGHT_BACKGROUND = 17,
    HIGHLIGHT_FOREGROUND = 19,
}

---@class OscGroup
---@field prefix string
---@field attribute ColorAttribute

---@type {[OscCode]: OscGroup}
M.OSC_GROUPS = {
    [M.OSC_CODES.PALETTE] = {
        prefix = "OscPalette",
        attribute = "fg",
    },
    [M.OSC_CODES.SPECIAL] = {
        prefix = "OscSpecial",
        attribute = "sp",
    },
    [M.OSC_CODES.BACKGROUND] = {
        prefix = "OscDefaultBackground",
        attribute = "bg",
    },
    [M.OSC_CODES.FOREGROUND] = {
        prefix = "OscDefaultForeground",
        attribute = "fg",
    },
    [M.OSC_CODES.CURSOR] = {
        prefix = "OscDefaultCursor",
        attribute = "fg",
    },
    [M.OSC_CODES.HIGHLIGHT_BACKGROUND] = {
        prefix = "OscDefaultHighlightBackground",
        attribute = "bg",
    },
    [M.OSC_CODES.HIGHLIGHT_FOREGROUND] = {
        prefix = "OscDefaultHighlightForeground",
        attribute = "fg",
    },
}

local group_name = "polychrome.osc"
local group = vim.api.nvim_create_augroup(group_name, {})

local function to_8_bit_value(input)
    -- get bit depth
    local depth = math.pow(16, #input)

    -- parse and normalize to 0.0 - 1.0
    local value = tonumber(input, 16)
    local cast = value / depth

    -- scale
    return string.format("%02x", cast * 256)
end

--- Parse an OSC 11 response
---
--- Either of the two formats below are accepted:
---
---   OSC 11 ; rgb:<red>/<green>/<blue>
---
--- or
---
---   OSC 11 ; rgba:<red>/<green>/<blue>/<alpha>
---
--- where
---
---   <red>, <green>, <blue>, <alpha> := h | hh | hhh | hhhh
---
--- @param resp string OSC 11 response
--- @return string? Red component
--- @return string? Green component
--- @return string? Blue component
--- @return string? Alpha component
function M.extract_osc_color_values(resp)
    local r, g, b
    r, g, b = resp:match("^rgb:(%x+)/(%x+)/(%x+)$")
    if r and g and b then
        return r, g, b, nil
    end

    local a
    r, g, b, a = resp:match("^rgba:(%x+)/(%x+)/(%x+)/(%x+)$")
    if not r or not g or not b or not a then
        return nil, nil, nil, nil
    end

    return r, g, b, a
end

--- @param code number
--- @param data_args (string|number)[]|nil
function M.osc_set(code, data_args)
    local response = nil
    local params = vim.iter({ { code }, data_args }):flatten():join(";")

    vim.api.nvim_create_autocmd("TermResponse", {
        group = group,
        nested = true,
        desc = "Detect OSC changes",
        callback = function(args)
            local resp = args.data.sequence ---@type string

            local data = resp:match("^\027%]" .. params .. ";(.+)$")
            if data == nil then
                return false
            end

            response = data
            return true
        end,
    })

    -- Wait for response
    vim.wait(100, function()
        return response ~= nil
    end, 1)

    return response
end

--- @param code number
--- @param data_args (string|number)[]|nil
function M._send_raw(code, data_args)
    local params = vim.iter({ { code }, data_args }):flatten():join(";")
    local osc_string = "\027]" .. params .. "\007"

    vim.api.nvim_ui_send(osc_string)
end

--- @param code number
--- @param data_args (string|number)[]|nil
function M.osc_query(code, data_args)
    -- append '?'
    data_args = data_args and data_args or {}
    table.insert(data_args, "?")

    return M.osc_set(code, data_args)
end

--- @param code number
--- @param data_args (string|number)[]|nil
function M.get_osc_color(code, data_args)
    local data = M.osc_query(code, data_args)
    if data == nil then
        return nil
    end

    return M.parse_osc_color(data)
end

---Parse a raw OSC response to a hex RGB string
---@param data string
---@return string?
function M.parse_osc_color(data)
    local r, g, b, a = M.extract_osc_color_values(data)
    if r == nil or g == nil or b == nil then
        return nil
    end

    return "#" .. vim.iter({ r, g, b, a }):map(to_8_bit_value):join()
end

---@param code OscCode
---@param args any[]
local function create_osc_group(code, args)
    local preset = M.OSC_GROUPS[code]

    -- OSC Palette response format: [<idx>, <color>]
    -- All others format: [<color>]
    local suffix = code == M.OSC_CODES.PALETTE and table.remove(args, 1) or ""
    local color = M.parse_osc_color(args[1])
    local name = preset.prefix .. suffix

    state.osc_groups[name] = Group.new(name, { [preset.attribute] = Color.from(color) })
end

local did_setup = false
---Setup OSC autodetection. Safe to call multiple times.
---@param config PolychromeFullConfig
function M.setup(config)
    if did_setup then
        return
    end

    local utils = require("polychrome.utils")
    local schedule_reload = utils.debounce(config.osc.debounce_ms, function()
        if state.current_colorscheme then
            state.current_colorscheme:reload()
        end
    end)

    vim.api.nvim_create_autocmd("TermResponse", {
        group = group,
        nested = true,
        desc = "Polychrome's autodetection of terminal color updates via OSC",
        callback = function(args)
            local resp = args.data.sequence ---@type string

            local data = resp:match("^\027%](.+)$")
            if data == nil then
                return
            end

            local parts = vim.split(data, ";")
            local code = tonumber(table.remove(parts, 1))

            if not code or not vim.tbl_contains(M.OSC_CODES, code) then
                return
            end

            create_osc_group(code, parts)

            schedule_reload()
        end,
    })

    -- send OSC sequence to initialize groups (if supported)
    for _, code in ipairs({
        M.OSC_CODES.SPECIAL,
        M.OSC_CODES.BACKGROUND,
        M.OSC_CODES.FOREGROUND,
        M.OSC_CODES.CURSOR,
        M.OSC_CODES.HIGHLIGHT_BACKGROUND,
        M.OSC_CODES.HIGHLIGHT_FOREGROUND,
    }) do
        M._send_raw(code, { "?" })
    end
    for palette_entry = 0, 255 do
        M._send_raw(M.OSC_CODES.PALETTE, { palette_entry, "?" })
    end

    did_setup = true
end

function M.disable()
    vim.api.nvim_del_augroup_by_id(group)
    did_setup = false
end

return M
