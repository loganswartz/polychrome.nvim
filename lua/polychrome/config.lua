local default_config = require("polychrome.config.default")

local M = {}

---@param config PolychromeConfig?
---@return PolychromeFullConfig
function M.make_config(config)
    local merged = vim.tbl_deep_extend("force", default_config, config or {})

    -- migrate existing configs
    if merged and merged.inject_gui_groups ~= nil then
        vim.deprecate(
            "config.inject_gui_groups",
            "config.gui_groups.enable",
            "future versions",
            "polychrome.nvim",
            false
        )
        merged.gui_groups.enable = merged.inject_gui_groups
        merged.inject_gui_groups = nil
    end

    -- autotransparency will not work without OSC enabled
    if merged.autotransparency.enable then
        merged.osc.enable = true
    end

    return merged
end

return M
