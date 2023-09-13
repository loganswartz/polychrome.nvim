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
local Colorscheme = require('polychrome').Colorscheme

Colorscheme:define('yourtheme', function ()
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

## Usage

If you want to dive into a complete example already using polychrome.nvim, check
out [`sunburn.nvim`](https://github.com/loganswartz/sunburn.nvim).

Here's some quick context for people who aren't familiar with how colorschemes
work in Vim/Neovim:

When you run `colorscheme <some name>`, Neovim looks through the runtimepath for
some file inside `<some runtimepath entry>/colors`, named `<some name>.vim` or
`<some name>.lua`, and if found, runs that file. Historically, colorschemes are
made by simply putting a bunch of `hi` commands in this file (if you want an
example of this, check out the `runtime/colors` directory of the neovim source).
Modern plugin managers like `lazy.nvim`, `pckr.nvim`, `vim-plug`, etc. will
handle adding plugins to the runtimepath, so setting up a plugin is simple if
you format your project properly.

### Getting Started

To get started, create a new folder / git repo, and inside that folder, create a
`colors` directory. Inside that directory, create `<theme name>.lua`, and
populate it with the following:

```lua
local Colorscheme = require('polychrome').Colorscheme

-- replace `yourtheme` with the name of your colorscheme
Colorscheme:define('yourtheme', function ()

    -- Normal { fg = rgb(150, 150, 219), bg = rgb(20, 20, 20) }

end):apply()
```

You can then start adding highlights! Here are some examples of the different
syntaxes and helpers that available:

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

 * RGB hex string (vim natively supports; just pass as a normal string)
 * Raw RGB values (the `rgb` helper)
 * Linear (non-gamma-corrected) RGB (`lrgb`)
 * HSL (`hsl`)
 * Oklab (`oklab`)
 * Oklch (`oklch`)
 * CIEXYZ (`ciexyz`)
 * (more eventually)

The helpers are automatically injected into the colorscheme definition context,
so you don't need to `require` them if you don't want to (although you can
anyway for clarity). If you prefer to import the helpers explicitly:

```lua
local rgb = require('polychrome').rgb
-- or:
local rgb = require('polychrome.color.rgb')
```

Colors are represented by tables, so there is no reason you can't define them
outside of a colorscheme definition. This makes it easy to define multiple
palettes, or collect all your colors in one location:

```lua
-- lua/yourtheme/palette.lua

local rgb = require('polychrome.color.rgb')

local palette = {
    red = rgb(255, 0, 0), -- specify values as individual arguments
    green = rgb({ 0, 255, 0 }), -- or pass an ordered table
    blue = rgb({ r = 0, g = 0, b = 255 }), -- or even specify the components by name
}

return palette
```

```lua
-- colors/yourtheme.lua

local Colorscheme = require('polychrome').Colorscheme
local palette = require('yourtheme.palette')

Colorscheme:define('yourtheme', function ()
    Normal { bg = palette.red }
end):apply()
```

In fact, you don't even need to define your colorscheme inside the
`colors/yourtheme.lua`; all that's needed is to call `apply()` on a colorscheme
object in `colors/yourtheme.lua`. An example will make this clearer:

```lua
-- lua/yourtheme/palette.lua

local rgb = require('polychrome.color.rgb')

local palette = {
    red = rgb(255, 0, 0),
    green = rgb({ 0, 255, 0 }),
    blue = rgb({ r = 0, g = 0, b = 255 }),
}

return palette
```

```lua
-- lua/yourtheme/highlights.lua

local Colorscheme = require('polychrome').Colorscheme
local palette = require('yourtheme.palette')

local yourtheme = Colorscheme:define('yourtheme', function ()
    Normal { bg = palette.red }
end)

return yourtheme
```

```lua
-- colors/yourtheme.lua

local yourtheme = require('yourtheme.highlights')

yourtheme:apply()
```

### Documentation for end users

When you go to write documentation for users of your colorscheme, assuming that
everything is set up correctly, all a user needs to do is install your plugin
and `polychrome.nvim`, and then run `colorscheme yourtheme`. Here's a simple
example of a config for `lazy.nvim`:

```lua
{
    'you/yourtheme',
    dependencies = {
        'loganswartz/polychrome.nvim'
    },
    config = function()
        vim.cmd.colorscheme 'yourtheme'
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
Colorscheme.define('yourtheme', function (_)
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
