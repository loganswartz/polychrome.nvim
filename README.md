# polychrome.nvim

A colorscheme creation micro-framework.

## About

`polychrome.nvim` is a colorscheme creation micro-framework for Neovim. The
main features of `polychrome` are:

* simple and terse syntax
* minimal boilerplate
* colors can be specified in many different colorspaces (`hsl`, `Oklab`, etc)
* automatic and accurate color clipping down to sRGB when needed

Here's a fully functional example of a (very basic) colorscheme defined with
`polychrome`:

```lua
-- colors/your_theme.lua

local Colorscheme = require('polychrome').Colorscheme

Colorscheme.define('your_theme', function ()
    Normal { fg = rgb(150, 150, 219), bg = rgb(20, 20, 20) }
    Comment { fg = rgb(135, 135, 135) }
    Conceal { fg = rgb(222, 222, 222), bg = Comment.fg }
    Cursor { Reverse }
    Directory { fg = '#00ffff' }
    SpellBad { Undercurl }
    Error { fg = 'red' }
    Todo { Error, Standout, Underdouble, Italic }

    Constant { fg = rgb(0, 255, 255) }
    Boolean { Constant }
    _'@string.escape' { Constant }
    _'@number' { Constant }
end):apply()
```

If you want to dive into a complete example already using polychrome.nvim, check
out [`sunburn.nvim`](https://github.com/loganswartz/sunburn.nvim).

## Quick Start

To start testing things out, open a new (empty) buffer and run `:Polychrome
template theme`. This will fill the buffer with an empty colorscheme that
contains all the most common highlight groups, and looks something like this:

```lua
local Colorscheme = require('polychrome').Colorscheme

-- replace `your_theme` with the name of your colorscheme
Colorscheme.define('your_theme', function ()
    -- Normal { }
    -- Comment { }

    -- ...many other highlight groups
end)
```

Then, run `:Polychrome preview` (or `:Polychrome preview start`) to enable the
live preview mode. You can then start setting highlights, and you'll instantly
see the changes in your current window. You can disable the live preview mode
with `:Polychrome preview stop`.

> [!IMPORTANT]
> If you are planning on creating a full colorscheme plugin, you may want to
> skip to the [Proper Project Structure](#proper-plugin-structure) section now
> to start with a flexible project structure.

## Usage

Check `:h polychrome-usage` and `:h polychrome-attributes` for more in-depth
documentation.

Here are a few examples of some of the different syntaxes and helpers that are
available:

```lua
    -- most groups can be specified like this
    Constant { fg = rgb(0, 255, 0), bg = '#ff0000' }

    -- specify a GUI feature
    Underline { underline = true }

    -- link a group to another one (equivalent to `:hi link Boolean Constant`)
    Boolean { Constant }

    -- groups that use `@` or other special characters (ex. treesitter groups)
    -- need a slightly different syntax: _'<name>' instead of <name>
    _'@punctuation.delimiter' { fg = rgb(0, 255, 0), bg = oklch(0, 0, 0) }
```

That example shows off the `rgb` and `oklch` helper commands, but quite a few
more color systems are supported:

 * RGB hex string (Neovim natively supports; just pass as a normal string)
 * Raw RGB values (the `rgb` helper)
 * Linear (non-gamma-corrected) RGB (`lrgb`)
 * HSL (`hsl`)
 * Oklab (`oklab`)
 * Oklch (`oklch`)
 * CIEXYZ (`ciexyz`)
 * LMS (`lms`)
 * (more eventually)

The helpers are automatically injected into the colorscheme definition context,
so you don't need to `require` them if you don't want to (although you can
anyway for clarity). Check out `:h polychrome-colorspaces` for more in-depth
info on all the available helpers.

### Proper Plugin Structure

Here's some quick context for people who aren't familiar with how colorschemes
work in Vim/Neovim:

When you run `colorscheme your_theme`, Neovim looks through the runtimepath for
some file inside `<some runtimepath entry>/colors`, named `your_theme.vim` or
`your_theme.lua`, and if found, runs that file. Historically, colorschemes are
made by simply putting a bunch of `hi` commands in this file (if you want an
example of this, check out the `runtime/colors` directory of the neovim source).
Modern plugin managers like `lazy.nvim`, `pckr.nvim`, `vim-plug`, etc. will
handle adding plugins to the runtimepath, so setting up a plugin is simple if
you format your project properly.

The quick start section is great for testing things out, but if you're writing a
full theme, it makes sense to set up a repo in a certain way, for maximum
flexibility. Here's my recommendation:

```
.
└── your_theme/
    ├── lua/
    │   └── your_theme/
    │       ├── highlights.lua
    │       ├── palette.lua
    │       └── init.lua
    └── colors/
        └── your_theme.lua
```

`highlights.lua` is where you'll define the bulk of your colorscheme, and this
is largely the same as the file shown in the Quick Start section:

```lua
-- your_theme/lua/your_theme/highlights.lua
local Colorscheme = require('polychrome').Colorscheme

local theme = Colorscheme.define('your_theme', function ()
    -- Normal { fg = rgb(150, 150, 219), bg = rgb(20, 20, 20) }
end)

return theme
```

`palette.lua` is where you'll define all your colors:

```lua
-- your_theme/lua/your_theme/palette.lua

local rgb = require('polychrome.color.rgb')

local palette = {
    red = rgb(255, 0, 0),
    green = rgb(0, 255, 0),
    blue = rgb(0, 0, 255),
}

return palette
```

`init.lua` can look something like this:

```lua
-- your_theme/lua/your_theme/init.lua

local theme = require('your_theme.highlights')

return theme
```

`colors/your_theme.lua` should then import your theme object and run `:apply()`
on it:

```lua
-- your_theme/colors/your_theme.lua

local theme = require('your_theme')
-- or
-- local theme = require('your_theme.highlights')

theme:apply()
```

This way, other plugins can use your palettes (via
`require('your_theme.palette')`) or other logic.

### Documentation for end users

When you go to write documentation for users of your colorscheme, assuming that
everything is set up correctly, all a user needs to do is install your plugin
and `polychrome.nvim`, and then run `colorscheme your_theme` somewhere in their
config. Here's a simple example of a spec for `lazy.nvim`:

```lua
{
    'you/your_theme',
    dependencies = {
        'loganswartz/polychrome.nvim'
    },
}
```

### Autoinjected Groups

By default, a few groups are automatically defined before your definition
function is run. These groups represent all the supported spcial GUI features
supported by Neovim at this time. Currently, this means:

```lua
    Strikethrough { strikethrough = true }
    Underline { underline = true }
    Underdouble { underdouble = true }
    Undercurl { undercurl = true }
    Underdotted { underdotted = true }
    Underdashed { underdashed = true }
    Reverse { reverse = true }
    Standout { standout = true }
    Bold { bold = true }
    Italic { italic = true }
```

These groups are not special in any way, so use them as you would any other:

```lua
    SpellBad { Underdotted }
    SpellCap { underdashed = Underdashed.underdashed }
```

You can overwrite any of these by simply specifying them yourself in your
definition, or you can disable the injection entirely by passing `{
inject_gui_groups = false }` as a third argument to `Colorscheme.define`:

```lua
Colorscheme.define('your_theme', function (_)
    ...
end, { inject_gui_groups = false })
```

### Live Preview

You can turn on a dynamic preview of your colorscheme via the `:Polychrome
preview start` command, or `require('polychrome.preview').start()` from a Lua
context.

When enabled, several things happen:

* The contents of the current buffer are run as a lua module
* Any colorscheme definitions are automatically captured and applied
* Every highlight group name found in the buffer is highlighted with that group
  (ex: every occurence of the string "Comment" in the buffer is highlighted with
  the `Comment` highlight group)

Additionally, diagnostics are created for any common issues or errors found in
the colorscheme definition. This creates a very tight feedback loop as you add
and tweak your highlights, and you can immediately see the effects of each
change as you make them.

## Finding highlight groups

There isn't a single authoritative source for all the most common highlight
groups used in Vim/Neovim, so here are some good places to get at least some of
the most common groups:

```
# docs for the most basic recommended highlight groups
:h group-name
:h highlight-groups

# docs for treesitter highlight groups
# also check https://github.com/nvim-treesitter/nvim-treesitter/blob/master/CONTRIBUTING.md#highlights
:h treesitter-highlight-groups

# show all highlight groups in your current (neo)vim session
:so $VIMRUNTIME/syntax/hitest.vim
```

## Chroma clipping

When converting from a larger gamut down into sRGB, chroma clipping is performed
using code adapted from Björn Ottosson's methods described
[here](https://bottosson.github.io/posts/gamutclipping/#source-code). The
clipping is performed in the Oklab colorspace, which should result in a very
accurate translation.
