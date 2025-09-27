local M = {}

M.get_clients = vim.lsp.get_clients

--- @param bufnr integer
--- @param row integer
--- @param col integer
--- @return fun(client: vim.lsp.Client): table
function M.create_params(bufnr, row, col)
  return function(client)
    local offset_encoding = client.offset_encoding
    local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, row, row + 1, true)

    if not ok then
      print(debug.traceback(string.format('ERROR: row %d is out of range: %s', row, lines)))
    end

    local line = lines and lines[1] or ''

    -- col can never be larger than number of chars on line
    col = math.min(col, #line)

    return {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      position = {
        line = row,
        character = vim.str_utfindex(line, client.offset_encoding, col)
      }
    }
  end
end

--- @param bufnr integer
--- @param method string
--- @param params_fn fun(client: vim.lsp.Client): table
--- @param handler fun(results: any[])
--- @param clients vim.lsp.Client[]
function M.buf_request_all(bufnr, method, params_fn, handler, clients)
  local results = {}
  local exp_reponses = 0
  local reponses = 0

  for _, client in pairs(clients) do
    if client:supports_method(method, bufnr) then
      exp_reponses = exp_reponses + 1
      client:request(method, params_fn(client), function(_, result)
        reponses = reponses + 1
        results[client] = result
        if reponses >= exp_reponses then
          handler(results)
        end
      end, bufnr)
    end
  end
end

return M
