local config = require('noteflow.config')
local utils = require('noteflow.utils')
local interp = utils.interp
local path = require('plenary.path')

local log = utils.log
local initialized = false

local M = {}

local client_id

function M._bufenter_handler(client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  local bufnr = vim.api.nvim_get_current_buf()

  client.request(
    'workspace/executeCommand',
    {command = "didFocusDocument", arguments = {vim.uri_from_bufnr(bufnr)}},
    nil,
    bufnr
  )
end

local function open_browser()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_client_by_id(client_id)

  client.request(
    'workspace/executeCommand',
    {command = "openBrowser", arguments = {vim.uri_from_bufnr(bufnr)}},
    nil,
    bufnr
  )
end

function M.open_preview()
  if not initialized then
    initialized = true
    M.setup()
    vim.api.nvim_command('LspStart')
  else
    open_browser()
  end
end

function M.setup()
  local configs = require'lspconfig/configs'
  local plugin_root
  for _, p in pairs(vim.api.nvim_list_runtime_paths()) do
    if string.find(p, 'noteflow.nvim$') then plugin_root = p end
  end

  if not plugin_root then
    log.info('Preview disabled. Could not find Noteflow plugin root path')
    return
  end

  local cmd = {'npm', 'run', '--silent', 'start'}
  local cmd_cwd = path:new(plugin_root, 'server'):absolute()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.workspace.executeCommand = { dynamicRegistration = true }

  configs['noteflow'] = {
    default_config = {
      capabilities = capabilities,
      commands = {},
      filetypes = {'markdown'},
      root_dir = function() return config.vault_dir end,
      log_level = vim.lsp.protocol.MessageType.Warning,
      on_exit = function(code, signal, client_id)
        vim.api.nvim_command('augroup! noteflow_lsp_bufenter')
        log.info(
          "Preview disabled. Initialize Noteflow by running 'npm install' and try again")
      end,
      on_init = function(client)
        client_id = client.id
        -- TODO handle vault_dir change
        vim.api.nvim_exec(interp([=[
augroup noteflow_lsp_bufenter
  au!
  au BufEnter ${path} lua require('noteflow.preview')._bufenter_handler(${client_id})
augroup END
        ]=], {client_id = client.id, path = config.vault_dir .. '/*.md'}), false)
      end
    }
  }

  require('lspconfig').noteflow.setup({cmd = cmd, cmd_cwd = cmd_cwd})

  --  https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp.lua#L1048
  -- NOTIFY https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp.lua#L450
end

return M
