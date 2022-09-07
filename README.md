# clangwarningparser.nvim

The goal of clangwarningparser.nvim is to make it easier to handle clang-tidy output files by parsing each arguments' contents and putting them in a list, also providing previews and jump-to-location.

## Table of contents

1. [Install](#install)
1. [Requirements](#requirements)
1. [Configuration](#configuration)

## Install

Using [packer](https://github.com/wbthomason/packer.nvim):
```lua
use {'strptrk/clangwarningparser.nvim'}
```

## Requirements

You have to enable `termguicolors` to have proper coloring.

```vim
set termguicolors
```
```lua
vim.o.termguicolors = true
```

## Configuration

The `setup` function takes a configuration table as an argument, or optionally nothing.

```lua
require('clangwarningparser').setup()
```

Default settings:

```lua
require('clangwarningparser').setup({
  float_opts = {
    width_percentage = 75,
    height_percentage = 75,
    border = 'rounded'
  },
  relative = true,
  width = 20,
  open_on_load = true,
  center_on_select = false,
  strict_bufname = true,
  root = "",
  root_env = "",
  root_cd = false,
  map_defaults = true,
  normalize_path = true,
  keymaps = {
    preview = {'o', 'p'},
    select_entry = '<CR>',
    toggle_win = '<leader>w',
    open_win = '<leader>Wo',
    close_win = '<leader>Wc',
    quit_preview = 'q',
    toggle_done = 'd'
  },
  colors = {
    done = "#05a623",
    preview_filepath = "#51D8FF",
    select_entry = "#93ccfa",
  },
})
```

Options:


- `float_opts`: options to control appearance of the preview window
    - `width_percentage`: width of the preview window relative to the editor size
    - `height_percentage`: height of the preview window relative to the editor size
    - `border`: border style of the preview window
        - possible values: 'none', 'single', 'double', 'rounded', 'solid', 'shadow'

- `relative` and `width`: if `relative` is `true`, then the `width` value is a percentage, relative to the editor size, if `relative` is `false`, then `width` represents the number of columns.

- `open_on_load`: `true` to open the sidebar when calling `CWParse`, `false` otherwise
- `center_on_select`: `true` to center the source code window when selecting the entry in the sidebar, `false` otherwise (`zz`)
- `strict_bufname`: `true` to only parse files ending with `.log` when calling `CWParse buffers`, `false` otherwise
- `root`: the project root directory
- `root_env`: the environmental variable which stores the project root directory
- `root_cd`: `true` if you want to `:cd` into the `root` or `root_env` directory, `false` otherwise
    - note: `root` takes precedence over `root_env`, if neither is given, the root will be set to $PWD
- `map_defaults`: `true` to set default keymaps to functions you do not map, `false` otherwise
- `normalize_path`: `true` to replace '../../' with 'root/' in file paths, `false` otherwise
- `keymaps`: each keymap is either a string or a table of strings
    - `preview`: opens the description of the error in a floating window
    - `select_entry`: jumpts to the location of the warning in your original window
    - `toggle_win`: toggles the sidebar
    - `open_win`: opens the sidebar
    - `close_win`: closes the sidebar
    - `quit_preview`: quits the floating preview window
    - `toggle_done`: marks currently selected entry as done or undone (by setting the foreground color)
- `colors`: the colors used by the plugin
    - `done`: the foreground color used to mark entries done
    - `preview_filepath`: the path's color in the floating preview window
    - `select_entry`: the foreground color of the currently hovered entry in the sidebar (background is the `CursorLine` highlight)
