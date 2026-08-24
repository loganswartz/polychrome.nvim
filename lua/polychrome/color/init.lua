local utils = require("polychrome.utils")

---@see Reference https://drafts.csswg.org/css-color/#color-conversion-code
local M = utils.load_submodules("polychrome.color", { exclude = { "base" } })
setmetatable(M, {
    __index = function(self, value)
        -- case-insensitive imports
        local lower = string.lower(value)
        return rawget(self, lower)
    end,
})

return M
