local api = vim.api
local wo = vim.wo
local cmd = vim.cmd
local map = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd
local ceil = math.ceil
local defcommand = vim.api.nvim_create_user_command

local M = {}
local LF = {}

local State = {
  warn_win = -1,
  warn_buf = -1,
  warns = {},
  hl_ns = -1,
  keys_mapped = false,
  root = '',
  width = -1;
}

local Config = {
  float_opts = {
    width_percentage = 75,
    height_percentage = 75,
    border = 'rounded',
  },
  relative = true,
  width = 20,
  open_on_load = true,
  center_on_select = false,
  strict_bufname = true,
  root = '',
  root_env = '',
  root_cd = false,
  map_defaults = true,
  normalize_path = true,
  keymaps = {
    preview = { 'o', 'p' },
    select_entry = { '<CR>' },
    toggle_win = { '<leader>w' },
    open_win = { '<leader>Wo' },
    close_win = { '<leader>Wc' },
    quit_preview = { 'q' },
    toggle_done = { 'd', '<tab>' },
  },
  colors = {
    done = '#05a623',
    preview_filepath = '#51D8FF',
    select_entry = '#93ccfa',
  },
}

local function ReadContents(file)
  local f = assert(io.open(file, 'rb'))
  local content = f:read('*all')
  f:close()
  return content
end

function string:split(split_pattern, result)
  if not result then
    result = {}
  end
  local start = 1
  local split_start, split_end = string.find(tostring(self), split_pattern, start)
  while split_start do
    table.insert(result, string.sub(tostring(self), start, split_start - 1))
    start = split_end + 1
    split_start, split_end = string.find(tostring(self), split_pattern, start)
  end
  table.insert(result, string.sub(tostring(self), start))
  return result
end

LF.ParseWarnings = function(str)
  local root = State.root
  local lines = str:split('\n')
  for i, v in pairs(lines) do
    if v:match('^%d+ warning[s]? generated') then
      lines[i] = nil
    else
      break
    end
  end -- for
  local warns = {}
  local warn_index = 0
  for _, line in pairs(lines) do
    local matching = line:match(':%d+:%d+: warning: ')
    local line_len = line:len()
    if matching then
      local lin, col = line:match(':(%d+):(%d+):')
      local file = line:match('^(.*):%d+:%d+:')
      local shortfile
      if Config.normalize_path and file:match('.*%.%./%.%./') then
        shortfile = file:match('.*%.%./%.%./(.*)')
        file = root .. '/' .. shortfile
      else
        shortfile = file:match(root .. '/(.*)')
        if not shortfile then
          shortfile = file
        end
      end
      local warn = line:match('^.*warning: (.*)')
      warn_index = warn_index + 1
      warns[warn_index] = {
        warn = { warn },
        file = file,
        shortfile = shortfile,
        line = tonumber(lin),
        col = tonumber(col),
        height = 1,
        width = line_len,
        done = false,
      }
    else -- matching
      if line_len > warns[warn_index].width then
        warns[warn_index].width = line_len
      end
      warns[warn_index]['height'] = warns[warn_index]['height'] + 1
      table.insert(warns[warn_index]['warn'], line)
    end -- matching
  end -- for
  return warns
end

LF.GetLine = function()
  return vim.api.nvim_win_get_cursor(0)[1]
end

LF.JumpToCodeWin = function()
  local curwin = vim.fn.winnr()
  cmd('wincmd h')
  if curwin == vim.fn.winnr() then
    cmd('wincmd v')
    api.nvim_win_set_width(0, State.width)
    cmd('wincmd h')
  end
end

LF.SelectEntry = function()
  local line = LF.GetLine()
  local w = State.warns[line]
  LF.JumpToCodeWin()
  cmd('edit ' .. w['file'])
  api.nvim_win_set_cursor(api.nvim_get_current_win(), {
    w['line'],
    w['col'] - 1,
  })
  if Config.center_on_select then
    cmd('norm zz')
  end
end

LF.PreviewWarn = function(warns, index, opts)
  opts = opts or {}
  local hp = opts.height_percentage or Config.float_opts.height_percentage
  local wp = opts.width_percentage or Config.float_opts.width_percentage
  local tmp_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(tmp_buf, 'bufhidden', 'wipe')
  State.width = math.min(warns[index].width, ceil(vim.o.columns * wp / 100))
  local wrapping = 0
  for _, w in pairs(warns[index]['warn']) do
    if w:len() > State.width then
      wrapping = wrapping + 1
    end
  end
  local height = math.min(warns[index].height + wrapping, ceil(vim.o.lines * hp / 100))
  api.nvim_buf_set_lines(tmp_buf, 0, 1, false, { warns[index]['shortfile'] })
  api.nvim_buf_add_highlight(tmp_buf, -1, 'ClangWarnsFilePath', 0, 0, -1)
  api.nvim_buf_set_lines(tmp_buf, 1, -1, false, warns[index]['warn'])
  local _ = api.nvim_open_win(tmp_buf, true, {
    relative = 'cursor',
    height = height + 1,
    width = State.width,
    row = 0,
    col = 0,
    style = 'minimal',
    border = opts.border or Config.float_opts.border,
  })
  wo.scrolloff = 0
  wo.sidescrolloff = 0
  wo.wrap = true
  LF.SetPreviewKeymaps(tmp_buf)
  api.nvim_buf_set_option(tmp_buf, 'modifiable', false)
end

LF.ClearHoverHl = function(bufnr)
  api.nvim_buf_clear_namespace(bufnr, State.hl_ns, 0, -1)
end

LF.SetupHls = function()
  if vim.fn.hlexists('ClangWarnsDone') == 0 then
    vim.api.nvim_set_hl(0, 'ClangWarnsDone', { fg = Config.colors.done })
  end
  if vim.fn.hlexists('ClangWarnsFilePath') == 0 then
    vim.api.nvim_set_hl(0, 'ClangWarnsFilePath', { fg = Config.colors.preview_filepath })
  end
  if vim.fn.hlexists('ClangWarnsSelect') == 0 then
    vim.api.nvim_set_hl(0, 'ClangWarnsSelect', { fg = Config.colors.select_entry })
  end
  if vim.fn.hlexists('ClangWarnsHover') == 0 then
    local cline_hl = vim.api.nvim_get_hl_by_name('CursorLine', true)
    local string_hl = vim.api.nvim_get_hl_by_name('ClangWarnsSelect', true)
    vim.api.nvim_set_hl(0, 'ClangWarnsHover', {
      bg = cline_hl.background,
      fg = string_hl.foreground,
    })
  end
end

LF.AddHoverHl = function(bufnr, line, col_start)
  vim.api.nvim_buf_add_highlight(bufnr, State.hl_ns, 'ClangWarnsHover', line, col_start, -1)
end

LF.AddDoneHl = function(bufnr, line, col_start)
  vim.api.nvim_buf_add_highlight(bufnr, State.hl_ns, 'ClangWarnsDone', line, col_start, -1)
end

LF.SetDone = function()
  local line = LF.GetLine()
  State.warns[line].done = not State.warns[line].done
end

LF.Refresh = function()
  LF.ClearHoverHl(State.warn_buf)
  for i, v in pairs(State.warns) do
    if v.done then
      LF.AddDoneHl(State.warn_buf, i - 1, 0)
    end
  end
  LF.AddHoverHl(State.warn_buf, LF.GetLine() - 1, 0)
end

LF.ToggleDone = function()
  LF.SetDone()
  vim.cmd([[norm j]])
  LF.Refresh()
end

LF.GetWindowWidth = function()
  if Config.relative then
    return math.ceil(vim.o.columns * (Config.width / 100))
  else
    return Config.width
  end
end

LF.WindowIsValid = function()
  return (api.nvim_win_is_valid(State.warn_win) and api.nvim_buf_is_valid(State.warn_buf))
end

LF.CloseWindow = function()
  if LF.WindowIsValid() then
    cmd('bwipeout! ' .. State.warn_buf)
  end
end

LF._FocusWindow = function()
  if LF.WindowIsValid() then
    vim.fn.win_gotoid(State.warn_win)
  end
end

LF.ToggleWindow = function()
  if LF.WindowIsValid() then
    cmd('bwipeout! ' .. State.warn_buf)
  else
    LF.OpenWindow()
  end
end

LF.GetBufferNames = function()
  local buffers_all = api.nvim_list_bufs()
  local buffers = {}
  for _, buf in pairs(buffers_all) do
    local name = api.nvim_buf_get_name(buf)
    if name ~= '' then
      if Config.strict_bufname then
        if name:match('%.log$') then
          table.insert(buffers, name)
        end
      else
        table.insert(buffers, name)
      end
    end
  end
  return buffers
end

LF.OpenWindow = function()
  if #State.warns == 0 then
    return
  end
  if LF.WindowIsValid() then
    return
  end
  State.warn_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(State.warn_buf, 'bufhidden', 'wipe')
  cmd('botright vs')
  cmd('vertical resize ' .. LF.GetWindowWidth())
  State.warn_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(State.warn_win, State.warn_buf)
  api.nvim_win_set_option(State.warn_win, 'number', false)
  api.nvim_win_set_option(State.warn_win, 'wrap', false)
  api.nvim_win_set_option(State.warn_win, 'relativenumber', false)
  api.nvim_win_set_option(State.warn_win, 'winfixwidth', true)
  api.nvim_win_set_option(State.warn_win, 'list', false)
  api.nvim_buf_set_name(State.warn_buf, 'Warnings')
  api.nvim_buf_set_option(State.warn_buf, 'filetype', 'Warnings')
  local warns_display = {}
  for _, v in pairs(State.warns) do
    table.insert(warns_display, v['warn'][1])
  end
  api.nvim_buf_set_lines(State.warn_buf, 0, -1, false, warns_display)
  api.nvim_buf_set_option(State.warn_buf, 'modifiable', false)
  autocmd('CursorMoved', {
    callback = function()
      LF.Refresh()
    end,
    buffer = State.warn_buf,
  })
  LF.SetWindowKeymaps()
  if Config.root_cd then
    cmd('cd ' .. State.root)
  end
end

LF.Load = function(args)
  local files = args.fargs
  if tostring(files[1]) == 'buffers' then
    files = LF.GetBufferNames()
  elseif files[1] == nil then
    files = { api.nvim_buf_get_name(0) }
  end
  State.hl_ns = api.nvim_create_namespace('CW_hlns')
  for _, file in ipairs(files) do
    for _, w in pairs(LF.ParseWarnings(ReadContents(file))) do
      table.insert(State.warns, w)
    end
  end
  LF.SetGlobalKeymaps()
  if Config.open_on_load then
    if LF.WindowIsValid() then
      vim.fn.win_gotoid(State.warn_win)
    else
      LF.OpenWindow()
    end
  end
end

local Keymaps = {
  window = {
    preview = {
      keys = {},
      fn = function()
        LF.PreviewWarn(State.warns, LF.GetLine(), Config.float_opts)
      end,
      desc = "Open Preview"
    },
    toggle_done = {
      keys = {},
      fn = LF.ToggleDone,
      desc = "Toggle Done"
    },
  },
  preview = {
    select_entry = {
      keys = {},
      fn = function(bufnr, inpreview)
        return function()
          if inpreview then
            cmd([[bwipeout! ]] .. bufnr)
          end
          LF.SelectEntry()
        end
      end,
      desc = "Select Entry"
    },
    quit_preview = {
      keys = {},
      fn = function(bufnr, _)
        return function()
          cmd([[bwipeout! ]] .. bufnr)
        end
      end,
      desc = "Quit Preview"
    },
  },
  global = {
    toggle_win = {
      keys = {},
      fn = LF.ToggleWindow,
      desc = "Toggle Sidebar"
    },
    open_win = {
      keys = {},
      fn = LF.OpenWindow,
      desc = "Open Sidebar"
    },
    close_win = {
      keys = {},
      fn = LF.CloseWindow,
      desc = "Close Sidebar"
    },
  },
}

LF.SetGlobalKeymaps = function()
  if State.keys_mapped then
    return
  else
    State.keys_mapped = true
  end
  for _, maptype in pairs(Keymaps.global) do
    for _, keym in ipairs(maptype.keys) do
      map({ 'n', 'v' }, keym, maptype.fn, { desc = maptype.desc })
    end
  end
end

LF.SetPreviewKeymaps = function(bufnr)
  for _, maptype in pairs(Keymaps.preview) do
    for _, keym in ipairs(maptype.keys) do
      map({ 'n', 'v' }, keym, maptype.fn(bufnr, true), { buffer = bufnr, desc = maptype.desc })
    end
  end
  map({ 'n', 'v' }, 'j', 'gj', { buffer = bufnr })
  map({ 'n', 'v' }, 'k', 'gk', { buffer = bufnr })
end

LF.SetWindowKeymaps = function()
  for _, maptype in pairs(Keymaps.window) do
    for _, keym in ipairs(maptype.keys) do
      map({ 'n', 'v' }, keym, maptype.fn, { buffer = State.warn_buf })
    end
  end
  local sel = Keymaps.preview.select_entry
  for _, keym in pairs(sel.keys) do
    map({ 'n', 'v' }, keym, sel.fn(0, false), { buffer = State.warn_buf })
  end
end

LF.CopyKeymaps = function(optskms)
  for k, _ in pairs(Keymaps) do
    for kk, _ in pairs(Keymaps[k]) do
      if type(optskms[kk]) == 'table' then
        Keymaps[k][kk].keys = optskms[kk]
      elseif Config.map_defaults and (optskms[kk] == nil) then
        Keymaps[k][kk].keys = Config.keymaps[kk]
      else
        Keymaps[k][kk].keys = { optskms[kk] }
      end
    end
  end
end

M.setup = function(opts)
  opts = opts or {}
  for key, val in pairs(Config) do
    if type(val) == 'table' then
      if not (key == 'keymaps') then
        for k, _ in pairs(val) do
          opts[key] = opts[key] or {}
          Config[key][k] = opts[key][k] or Config[key][k]
        end
      end
    else
      if opts[key] ~= nil then
        Config[key] = opts[key]
      end
    end
  end
  if Config.root ~= '' then
    State.root = Config.root
  else
    State.root = os.getenv(Config.root_env or '') or os.getenv('PWD')
  end
  LF.CopyKeymaps(opts.keymaps or {})
  LF.SetupHls()
  defcommand('CWParse', function(args)
    LF.Load(args)
  end, {
    force = true,
    nargs = '*',
  })
end

return M
