rockspec_format = "3.0"
package = "polychrome.nvim"
version = "scm-1"

test_dependencies = {
    "lua >= 5.1",
    "nlua",
    "nui.nvim",
}

source = {
    url = "git://github.com/loganswartz/" .. package,
}

build = {
    type = "builtin",
}
