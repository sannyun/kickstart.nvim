local M = {}

--- Send a request to rust-analyzer with position params for the cursor location.
---@param method string LSP method name
---@param callback fun(err: lsp.ResponseError?, result: any)
local function send_request(method, callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local attached_clients = vim.lsp.get_clients {
    bufnr = bufnr,
    name = 'rust_analyzer',
    method = method,
  }

  if #attached_clients == 0 then
    vim.notify('rust-analyzer not attached or does not support ' .. method, vim.log.levels.ERROR)
    return
  end

  local active_client = attached_clients[1]
  local params = vim.lsp.util.make_position_params(0, active_client.offset_encoding or 'utf-8')

  active_client:request(method, params, callback, bufnr)
end

--- Request test runnables from rust-analyzer at the cursor position,
--- filter for tests, and pass the selected runnable to the callback.
---@param callback fun(test: table)
local function get_test_runnable(callback)
  send_request('experimental/runnables', function(err, result)
    if err ~= nil then
      vim.notify('Failed to get runnables: ' .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end

    if not result or #result == 0 then
      vim.notify('No runnables found at cursor position', vim.log.levels.WARN)
      return
    end

    local tests = vim.tbl_filter(function(runnable)
      return runnable.label:match '^test' or runnable.label:match '^doctest'
    end, result)

    if #tests == 0 then
      vim.notify('No tests found at cursor position', vim.log.levels.WARN)
      return
    end

    if #tests == 1 then
      callback(tests[1])
    else
      vim.ui.select(tests, {
        prompt = 'Select test:',
        format_item = function(item)
          return item.label
        end,
      }, function(choice)
        if choice then
          callback(choice)
        end
      end)
    end
  end)
end

--- Build a cargo command from runnable args.
---@param args table runnable args from rust-analyzer
---@param extra_cargo_args? string[] additional cargo args (e.g. {"--no-run"})
---@return string[]
local function build_cargo_cmd(args, extra_cargo_args)
  local cmd = { args.overrideCargo or 'cargo' }
  vim.list_extend(cmd, args.cargoArgs)
  if args.cargoExtraArgs and #args.cargoExtraArgs > 0 then
    vim.list_extend(cmd, args.cargoExtraArgs)
  end
  if extra_cargo_args then
    vim.list_extend(cmd, extra_cargo_args)
  end
  if args.executableArgs and #args.executableArgs > 0 then
    table.insert(cmd, '--')
    vim.list_extend(cmd, args.executableArgs)
  end
  return cmd
end

--- Build the test binary with --no-run and parse JSON output to find the executable path.
--- Calls callback(executable_path) on success, or notifies on failure.
---@param args table
---@param callback fun(executable: string)
local function discover_test_binary(args, callback)
  local cmd = build_cargo_cmd(args, { '--no-run', '--message-format=json' })

  local output = {}
  vim.fn.jobstart(cmd, {
    cwd = args.workspaceRoot,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        -- stderr contains cargo's progress messages, ignore unless we fail
        vim.list_extend(output, data)
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          vim.notify('Failed to build test binary (exit ' .. exit_code .. ')', vim.log.levels.ERROR)
          return
        end

        -- Find the last compiler-artifact with a non-null executable
        local executable = nil
        for _, line in ipairs(output) do
          local ok, decoded = pcall(vim.json.decode, line)
          if ok and decoded and decoded.reason == 'compiler-artifact' and decoded.executable then
            executable = decoded.executable
          end
        end

        if not executable then
          vim.notify('Could not determine test binary path', vim.log.levels.ERROR)
          return
        end

        callback(executable)
      end)
    end,
  })
end

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
    send_request('rust-analyzer/expandMacro', function(err, result)
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

      vim.list_extend(lines, vim.split(result.expansion, '\n', { trimempty = true }))

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
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
    end)
  end, '[R]ust [E]xpand Macro')

  map('<leader>rt', function()
    get_test_runnable(function(test)
      local cmd = build_cargo_cmd(test.args)

      vim.cmd 'split'
      local term_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, term_buf)
      vim.fn.jobstart(cmd, {
        term = true,
        cwd = test.args.workspaceRoot,
        on_exit = function(_, exit_code)
          if exit_code == 0 then
            vim.notify('Test passed: ' .. test.label, vim.log.levels.INFO)
          else
            vim.notify('Test failed: ' .. test.label, vim.log.levels.ERROR)
          end
        end,
      })
    end)
  end, '[R]un [T]est')

  map('<leader>rd', function()
    get_test_runnable(function(test)
      vim.notify('Building test binary...', vim.log.levels.INFO)

      discover_test_binary(test.args, function(executable)
        -- Build the args to pass to the test binary to select the specific test
        local test_args = {}
        if test.args.executableArgs and #test.args.executableArgs > 0 then
          vim.list_extend(test_args, test.args.executableArgs)
        end

        local dap = require 'dap'
        dap.run {
          type = 'codelldb',
          request = 'launch',
          name = 'Debug: ' .. test.label,
          program = executable,
          args = test_args,
          cwd = test.args.workspaceRoot,
          stopOnEntry = false,
        }
      end)
    end)
  end, '[R]ust [D]ebug Test')
end

return M
