local colorscheme = require("polychrome.colorscheme")
local color = require("polychrome.color")
local commands = require("polychrome.commands")

local M = {
    Colorscheme = colorscheme.Colorscheme,
}
setmetatable(M, {
    __index = function(_, value)
        return color[value]
    end,
})

commands.setup()

return M
