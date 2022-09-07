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
`float_opts`: options to control appearance of the preview window
- `width_percentage`: width of the preview window relative to the editor size
- `height_percentage`: height of the preview window relative to the editor size
- `border`: border style of the preview window
