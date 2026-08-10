---@class (partial) PolychromeConfig : PolychromeFullConfig
---@field autotransparency PolychromeAutotransparencyConfig?
---@field osc PolychromeOscConfig?
---@field gui_groups PolychromeGuiGroupsConfig?

---@class PolychromeFullConfig
---@field autotransparency PolychromeAutotransparencyFullConfig
---@field osc PolychromeOscFullConfig
---@field gui_groups PolychromeGuiGroupsConfig
local M = {}

---@class PolychromeAutotransparencyMatch
---@field matches string
---@field attribute string

---@alias PolychromeAutotransparencyGroups {[string]: PolychromeAutotransparencyMatch?}

---@class (partial) PolychromeAutotransparencyConfig : PolychromeAutotransparencyFullConfig
---@field enable boolean?
---@field groups PolychromeAutotransparencyGroups?

---Configuration options related to autotransparency.
---
---See `:h polychrome-autotransparency`
---@class PolychromeAutotransparencyFullConfig
---@field enable boolean
---@field groups PolychromeAutotransparencyGroups
M.autotransparency = {
    enable = false,
    groups = {
        Normal = {
            matches = "OscDefaultBackground",
            attribute = "bg",
        },
    },
}

---@class (partial) PolychromeOscConfig : PolychromeOscFullConfig
---@field enable boolean? Should OSC groups be automatically defined?
---@field debounce_ms number? How long should colorscheme reload calls be debounced for?

---Configuration options related to OSC support.
---
---See `:h polychrome-osc` for more info.
---@class PolychromeOscFullConfig
---@field enable boolean Should OSC groups be automatically defined?
---@field debounce_ms number How long should colorscheme reload calls be debounced for?
M.osc = {
    enable = false,
    debounce_ms = 50,
}

---@class (partial) PolychromeGuiGroupsConfig : PolychromeGuiGroupsFullConfig
---@field enable boolean? Should some default groups be automatically defined?

---Configuration options related to autognerated GUI groups.
---@class PolychromeGuiGroupsFullConfig
---@field enable boolean Should some default groups be automatically defined?
M.gui_groups = {
    enable = true,
}

return M
