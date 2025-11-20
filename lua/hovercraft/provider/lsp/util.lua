local M = {}

M.get_clients = vim.lsp.get_clients

--- @param params? table
--- @return fun(client: vim.lsp.Client): lsp.TextDocumentPositionParams
function M.client_positional_params(params)
  local win = vim.api.nvim_get_current_win()
  return function(client)
    local ret = vim.lsp.util.make_position_params(win, client.offset_encoding)
    if params then
      ret = vim.tbl_extend('force', ret, params)
    end
    return ret
  end
end

return M
