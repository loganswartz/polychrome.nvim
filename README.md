# polychrome.nvim

A colorscheme creation micro-framework.

## About

The main goal of `polychrome` is simplicity, both in UX and DX. By simplicity, I
mean:

 * simple and terse syntax
 * takes care of the typical colorscheme boilerplate
 * allows specifying colors in gamuts other than sRGB
 * automatically and intelligently clips colors in wide gamuts down to sRGB
 * inner workings are dead-simple to understand and modify
 * has minimal magic

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
    Directory { fg = rgb(0, 255, 255) }
    SpellBad { Undercurl }

    Constant { fg = rgb(0, 255, 255) }
    Boolean { Constant }
    _'@string.escape' { Constant }
    _'@number' { Constant }
end):apply()
```

If you want to dive into a complete example already using polychrome.nvim, check
out [`sunburn.nvim`](https://github.com/loganswartz/sunburn.nvim).

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

## Quick Start

If you just want to start testing things out, create a file named
`your_theme.lua`, and populate it with the following:

```lua
local Colorscheme = require('polychrome').Colorscheme

-- replace `your_theme` with the name of your colorscheme
Colorscheme.define('your_theme', function ()
    -- Normal { fg = rgb(150, 150, 219), bg = rgb(20, 20, 20) }
end)
```

Then, while editing that file, do `:StartPreview`.

You can then start adding highlights, and you'll instantly see the changes in
your current window.

> [!IMPORTANT]
> If you are planning on creating a full colorscheme plugin, you may want to
> skip to the [Proper Project Structure](#proper-plugin-structure) section now
> to start with a flexible project structure.

## Usage

Here are some examples of the different syntaxes and helpers that available:

```lua
    -- most groups can be specified like this
    Constant { fg = rgb(0, 255, 0), bg = '#ff0000' }

    -- specify a GUI feature
    Underline { gui = 'underline' }
    -- we actually inject all the common GUI helpers for convenience
    -- (this is documented later on in the README)

    -- link a group to another one (equivalent to `:hi link Boolean Constant`)
    Boolean { Constant }

    -- groups that use `@` or other special characters (ex. treesitter groups)
    -- need a slightly different syntax: _'<name>' instead of <name>
    _'@punctuation.delimiter' { fg = rgb(0, 255, 0), bg = oklch(0, 0, 0) }

    -- linking groups with special characters works similarly to normal
    _'@punctuation.delimiter' { Constant }
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
anyway for clarity). If you prefer to import the helpers explicitly:

```lua
local rgb = require('polychrome').rgb
-- or:
local rgb = require('polychrome.color.rgb')
```

Colors are objects (tables), so there is no reason you can't define and
manipulate them outside of a colorscheme definition. This makes it easy to
define multiple palettes, or collect all your colors in one location:

```lua
-- lua/your_theme/palette.lua

local rgb = require('polychrome.color.rgb')

local palette = {
    red = rgb(255, 0, 0), -- specify values as individual arguments
    green = rgb({ 0, 255, 0 }), -- or pass an ordered table
    blue = rgb({ r = 0, g = 0, b = 255 }), -- or even specify the components by name
}

return palette
```

```lua
-- colors/your_theme.lua

local Colorscheme = require('polychrome').Colorscheme
local palette = require('your_theme.palette')

Colorscheme.define('your_theme', function ()
    Normal { bg = palette.red }
end):apply()
```

In fact, you don't even need to define your colorscheme inside the
`colors/your_theme.lua`; all that's needed is to call `apply()` on a colorscheme
object in `colors/your_theme.lua`:

```lua
-- lua/your_theme/highlights.lua

local Colorscheme = require('polychrome').Colorscheme
local palette = require('your_theme.palette')

local your_theme = Colorscheme.define('your_theme', function ()
    Normal { bg = palette.red }
end)

return your_theme
```

```lua
-- colors/your_theme.lua

local your_theme = require('your_theme.highlights')

your_theme:apply()
```

Since colorschemes are just tables, you can treat them like objects, and do
things like providing several variants of your colorscheme. Here's a simple
example:

```lua
-- colors/your_theme.lua

local your_theme = require('your_theme.main')
local youralternatetheme = require('your_theme.alternate')

local alternate = vim.g.your_theme_variant == 'alternate'
local theme = alternate and your_alternate_theme or your_theme

theme:apply()
```

### Proper Plugin Structure

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
and `polychrome.nvim`, and then run `colorscheme your_theme`. Here's a simple
example of a config for `lazy.nvim`:

```lua
{
    'you/your_theme',
    dependencies = {
        'loganswartz/polychrome.nvim'
    },
    config = function()
        vim.cmd.colorscheme 'your_theme'
    },
}
```

### Autoinjected Groups

By default, a few groups are automatically defined before your definition
function is run. These groups represent all the supported spcial GUI features
supported by Neovim at this time. Currently, this means:

```lua
    Strikethrough { gui = "strikethrough" }
    Underline { gui = "underline" }
    Underdouble { gui = "underdouble" }
    Undercurl { gui = "undercurl" }
    Underdotted { gui = "underdotted" }
    Underdashed { gui = "underdashed" }
    Reverse { gui = "reverse" }
    Standout { gui = "standout" }
    Bold { gui = "bold" }
    Italic { gui = "italic" }
```

These groups are not special in any way, so use them as you would any other:

```lua
    SpellBad { Underdotted }
    SpellCap { gui = Underdashed.gui }
    -- of course, you can also just use the regular feature name directly
    SpellLocal { gui = "underdouble" }
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

You can turn on a dynamic preview of your colorscheme via the `:StartPreview`
command, or `require('polychrome').StartPreview()` from a Lua context. Running
this command does the following:

  1. Runs the contents of the current buffer, and reapplies any colorscheme
     defined anywhere within it (even via `require`).
  2. Get the names of all active highlight groups, and applies those groups to
     all literal strings in the current buffer matching those names (ie. all
     occurences of `Comment` in the buffer will be highlighted with the
     "Comment" highlight group)

`StartPreview()` registers these actions via autocmd (specifically
`TextChanged`, `TextChangedI`, `TextChangedP`, and `TextChangedT`), and
throttles reloads to every 500ms by default, shared across the autocommands.

You can deactivate the live editing mode with `:StopPreview`, or
`require('polychrome').StopPreview()` from a Lua context.

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
