local async = require('plenary.async')
local has_winbar = vim.fn.has('nvim-0.8') == 1

local M = {}

---@alias Hovercraft.UI.ShowOpts { current_provider?: string, }

---@class Hovercraft.UI.Options
---@field width? integer
---@field height? integer
---@field wrap_at? integer
---@field pad_top? integer
---@field pad_bottom? integer
---@field max_width? integer
---@field max_height? integer
---@field border? Hovercraft.UI.Border

---@alias Hovercraft.UI.Border 'none' | 'single' | 'double' | 'rounded' | 'solid' | 'shadow' | Hovercraft.UI.Border.Tile
---@alias Hovercraft.UI.Border.Tile { [1]: string, [2]: string } | string
---@alias Hovercraft.UIBorder.Table Hovercraft.UI.Border.Tile[]

---@class Hovercraft.UI.CurrentWindowConfig
---@field active_provider string
---@field providers string[]
---@field winnr integer
---@field bufnr integer
---@field origin_bufnr integer bufnr of the buffer that triggered the hover

---@alias Hovercraft.UI.OnShow fun(bufnr: number)
---@alias Hovercraft.UI.OnHide fun(bufnr: number)

---@class Hovercraft.UI
---@field config Hovercraft.UI.Options
---@field providers Hovercraft.Providers
---@field current_run integer
---@field window_config? Hovercraft.UI.CurrentWindowConfig
---@field on_show_listeners Hovercraft.UI.OnShow[]
---@field on_hide_listeners Hovercraft.UI.OnHide[]
local UI = {}

UI.__index = UI

---@param providers Hovercraft.Providers
---@param opts Hovercraft.UI.Options
---@return Hovercraft.UI
function M.new(providers, opts)
  return setmetatable({
    config = opts,
    providers = providers,
    current_run = 0,
    on_show_listeners = {},
    on_hide_listeners = {},
  }, UI)
end

---@param listener Hovercraft.UI.OnShow
function UI:register_onshow(listener)
  table.insert(self.on_show_listeners, listener)
end

---@param bufnr number
function UI:_fire_onshow(bufnr)
  for _, l in ipairs(self.on_show_listeners) do
    l(bufnr)
  end
end

---@param listener Hovercraft.UI.OnHide
function UI:register_onhide(listener)
  table.insert(self.on_hide_listeners, listener)
end

---@param bufnr number
function UI:_fire_onhide(bufnr)
  for _, l in ipairs(self.on_hide_listeners) do
    l(bufnr)
  end
end

---@param active_provider string
---@param provider_ids string[]
---@return string title
---@return integer title_length
function UI:_build_title(active_provider, provider_ids)
  local title = {}
  local winbar_length = 0

  for _, id in ipairs(provider_ids) do
    local p = self.providers:get_provider(id)

    if not p then
      -- if we do not find a provider for a given id, we messed up and it is a bug
      error(string.format('could not find provider for id `%s`! This should not happen!', id))
    end

    local hl = id == active_provider and 'TabLineSel' or 'TabLineFill'
    title[#title + 1] = string.format('%%#%s# %s ', hl, p.title)
    title[#title + 1] = '%#Normal#'
    winbar_length = winbar_length + #p.title + 2 -- + 2 for whitespace padding
  end

  return table.concat(title, ''), winbar_length
end

---@param winnr integer
---@param title string
---@param title_length integer
local function add_title(winnr, title, title_length)
  if not has_winbar then
    vim.notify_once('hover.nvim: `config.title` requires neovim >= 0.8.0',
      vim.log.levels.WARN)
    return
  end

  local config = vim.api.nvim_win_get_config(winnr)

  vim.api.nvim_win_set_config(winnr, {
    height = config.height + 1,
    width = math.max(config.width, title_length + 2) -- + 2 for border
  })

  vim.wo[winnr].winbar = title
end

---@private
--- Creates autocommands to close a preview window when events happen.
---
---@param events table list of events
---@param winnr integer window id of preview window
---@param bufnrs table list of buffers where the preview window will remain visible
function UI:_close_preview_autocmd(events, winnr, bufnrs)
  local augroup = vim.api.nvim_create_augroup('preview_window_' .. winnr, {
    clear = true,
  })

  -- close the preview window when entered a buffer that is not
  -- the floating window buffer or the buffer that spawned it
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function()
      if self.window_config and self.window_config.bufnr ~= vim.api.nvim_get_current_buf() then
        vim.schedule(function()
          self:hide()
        end)
      end
    end,
  })

  if #events > 0 then
    vim.api.nvim_create_autocmd(events, {
      group = augroup,
      buffer = bufnrs[2],
      callback = function()
        vim.schedule(function()
          self:hide()
        end)
      end,
    })
  end
end

---@param bufnr number
---@return string[]
function UI:_get_active_provider_ids(bufnr, pos)
  ---@type string[]
  local result = {}

  for _, provider in ipairs(self.providers:get_providers()) do
    if provider.is_enabled({ bufnr = bufnr, pos = pos }) then
      table.insert(result, provider.id)
    end
  end

  return result
end

---@param opts? Hovercraft.UI.ShowOpts
function UI:show(opts)
  opts = opts or {}

  -- the modulo operant is here only to prevent a potential integer overflow
  -- there is probably a better solution for this
  -- TODO: find better solution for abording old results
  local current_run = (self.current_run + 1) % 10000
  self.current_run = current_run

  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)

  async.void(function()
    local active_providers

    if self.window_config and self.window_config.providers then
      active_providers = self.window_config.providers
    else
      active_providers = self:_get_active_provider_ids(bufnr, pos)
    end

    if #active_providers == 0 then
      UI._show_no_provider_warning()
      return
    end

    local provider_id = opts.current_provider or active_providers[1]
    local provider = self.providers:get_provider(provider_id)

    if not provider then
      vim.notify(string.format('no provider for id "%s"!', provider_id))
      return
    end

    local result = provider.execute({
      bufnr = bufnr,
      pos = pos,
    }) or {}

    -- this should somewhat preevnt the issues of calling show in fast succession and
    -- only show the last result
    if current_run ~= self.current_run then
      return
    end

    if self:is_visible() then
      self:hide()
    end

    local contents ---@type string[]

    local filetype = result.filetype or 'markdown'

    if filetype == 'plaintext' then
      contents = result.lines or {}
    else
      contents = vim.lsp.util.convert_input_to_markdown_lines(result.lines or {})
    end

    if vim.tbl_isempty(contents) then
      contents = { '-- No information available --' }
    end

    local title, title_length = self:_build_title(provider_id, active_providers)

    local window_opts = vim.tbl_deep_extend('force', self.config, opts, { close_events = {} })
    local floating_bufnr, floating_winnr = vim.lsp.util.open_floating_preview(contents, filetype, window_opts)

    if result.customize then
      result.customize({ bufnr = floating_bufnr, winnr = floating_winnr })
    end

    self:_close_preview_autocmd(
      { 'CursorMoved', 'CursorMovedI', 'InsertCharPre' },
      floating_winnr,
      { floating_bufnr, bufnr }
    )

    add_title(floating_winnr, title, title_length)

    self.window_config = {
      active_provider = provider_id,
      bufnr = floating_bufnr,
      origin_bufnr = bufnr,
      winnr = floating_winnr,
      providers = active_providers,
    }

    self:_fire_onshow(bufnr)
  end)()
end

---@param providers string[]
---@param current_provider_id string
---@param step number steps to find next provider. can also be negative to step backwards
---@param cycle boolean if true, the providers are treated as a ringbuffer and one can scroll through them
---@return string
function M._get_next_provider_id(providers, current_provider_id, step, cycle)
  local found_index = -1

  for i, p in ipairs(providers) do
    if p == current_provider_id then
      found_index = i
      break
    end
  end

  if found_index < 1 then
    -- this should never happen and is clearly indicates a bug
    error(string.format([[couldn't find provider for id `%s`]], current_provider_id))
  end

  local next_provider_index

  if cycle then
    -- we need to adjust it +1 as lua arrays start indexing at 1
    next_provider_index = ((found_index + step - 1) % #providers) + 1
  else
    -- in case we are not cycling we need to do some more logic to ensure
    -- to either show the first or last provider
    local adjusted_index = found_index + step

    if adjusted_index < 1 then
      next_provider_index = 1
    else
      next_provider_index = math.min(adjusted_index, #providers)
    end
  end

  return providers[next_provider_index]
end

---@alias Hovercraft.UI.ShowNextOpts {cycle?: boolean, step? : number}

---@param opts Hovercraft.UI.ShowNextOpts
function UI:show_next(opts)
  opts = vim.tbl_deep_extend('keep', opts or {}, { cycle = true, step = 1 })

  vim.validate {
    cycle = { opts.cycle, 'boolean' },
    step = { opts.step, 'number' },
  }

  local bufnr = vim.api.nvim_get_current_buf()
  ---@type string
  local provider_id

  local providers
  local pos = vim.api.nvim_win_get_cursor(0)

  async.void(function()
    -- TODO: this needs to be reworked, as the figuring out which proivder is active is done twice
    if self.window_config and self.window_config.providers then
      providers = self.window_config.providers
    else
      providers = self:_get_active_provider_ids(bufnr, pos)
    end

    if #providers == 0 then
      UI._show_no_provider_warning()
      return
    end

    if self:is_visible() then
      -- if the window is visible, window_config will always be set
      local current_provider = self.window_config.active_provider

      provider_id = M._get_next_provider_id(providers, current_provider, opts.step, opts.cycle)
    else
      provider_id = providers[1]
    end

    self:show({ current_provider = provider_id })
  end)()
end

function UI._show_no_provider_warning()
  vim.print('No active providers for line!')
end

function UI:show_select()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_position(0)

  ---@type string[]
  local providers

  async.void(function()
    -- TODO: this needs to be reworked, as the figuring out active providers is done twice
    if self.window_config and self.window_config.providers then
      providers = self.window_config.providers
    else
      providers = self:_get_active_provider_ids(bufnr, pos)
    end

    if #providers == 0 then
      UI._show_no_provider_warning()
      return
    end

    local providers_to_select = {}

    for _, p in ipairs(providers) do
      table.insert(providers_to_select, {
        id = p,
        title = self.providers:get_provider(p).title or p
      })
    end

    vim.ui.select(providers_to_select, {
        prompt = 'Select hover provider:',
        format_item = function(item)
          return item.title
        end,
      },
      function(choice)
        if choice then
          self:show({ current_provider = choice.id })
        end
      end
    )
  end)()
end

---@param ui Hovercraft.UI
local function _hide_cleanup(ui)
  ui.window_config = nil
  ui.current_run = -1
end

function UI:hide()
  if not self:is_visible() then
    _hide_cleanup(self)
    return
  end

  vim.api.nvim_win_hide(self.window_config.winnr)

  local origin_bufnr = self.window_config.origin_bufnr

  _hide_cleanup(self)
  self:_fire_onhide(origin_bufnr)
end

---@return boolean
function UI:is_visible()
  if not self.window_config then
    return false
  end

  return vim.api.nvim_win_is_valid(self.window_config.winnr)
end

---@class Hovercraft.UI.ScrollOptions
---@field delta integer amount of lines to scroll (can also be negative)

---@param opts Hovercraft.UI.ScrollOptions
function UI:scroll(opts)
  if not self:is_visible() then
    return
  end

  vim.validate {
    delta = { opts.delta, 'number' }
  }

  local count = math.abs(opts.delta)
  local cmd

  if opts.delta < 0 then
    cmd = [[\<C-y>]]
  else
    cmd = [[\<C-e>]]
  end

  vim.api.nvim_win_call(self.window_config.winnr, function()
    vim.cmd('exec "normal! ' .. count .. cmd .. '"')
  end)
end

function UI:enter_popup()
  if not self:is_visible() then
    return
  end

  vim.api.nvim_set_current_win(self.window_config.winnr)
end

return M
