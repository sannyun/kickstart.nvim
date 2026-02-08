local M = {}

function M.setup(event)
  -- Only setup keybindings for Rust files
  if vim.bo[event.buf].filetype ~= 'rust' then
    return
  end

  -- Get the client that just attached
  local client = vim.lsp.get_client_by_id(event.data.client_id)

  -- Only set up keybindings for rust-analyzer
  if not client or client.name ~= 'rust_analyzer' then
    return
  end

  local map = function(keys, func, desc)
    vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
  end

  map('<leader>re', function()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Get rust-analyzer client for this buffer that supports the method
    local attached_clients = vim.lsp.get_clients {
      bufnr = bufnr,
      name = 'rust_analyzer',
      method = 'rust-analyzer/expandMacro',
    }

    if #attached_clients == 0 then
      vim.notify('rust-analyzer not attached or does not support expandMacro', vim.log.levels.ERROR)
      return
    end

    local active_client = attached_clients[1]
    local params = vim.lsp.util.make_position_params(0, active_client.offset_encoding or 'utf-8')

    local function response_handler(err, result)
      if err ~= nil then
        vim.notify('Macro expansion failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end

      if not result or not result.expansion then
        vim.notify('No macro at cursor position', vim.log.levels.WARN)
        return
      end

      local lines = {}
      table.insert(lines, '// Macro expansion for ' .. result.name)
      table.insert(lines, '')

      for line in result.expansion:gmatch '(.-)\n' do
        table.insert(lines, line)
      end

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
      vim.api.nvim_set_option_value('filetype', 'rust', { buf = buf })

      local width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
      local height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))
      local row = math.ceil(vim.o.lines - height) * 0.5 - 1
      local col = math.ceil(vim.o.columns - width) * 0.5 - 1
      vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = col,
        row = row,
        anchor = 'NW',
        border = 'single',
        style = 'minimal',
      })
    end

    -- Use vim.lsp.buf_request to handle routing to the correct client
    vim.lsp.buf_request(0, 'rust-analyzer/expandMacro', params, response_handler)
  end, '[R]ust [E]xpand Macro')
end

return M
