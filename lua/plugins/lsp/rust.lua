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

--- Request runnables from rust-analyzer at the cursor position,
--- filter for actionable targets (run/test/doctest), and pass the selected runnable to the callback.
---@param callback fun(runnable: table)
local function get_runnable(callback)
  send_request('experimental/runnables', function(err, result)
    if err ~= nil then
      vim.notify('Failed to get runnables: ' .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end

    if not result or #result == 0 then
      vim.notify('No runnables found at cursor position', vim.log.levels.WARN)
      return
    end

    local targets = vim.tbl_filter(function(runnable)
      local label = runnable.label
      return label:match '^test ' or label:match '^doctest' or label:match '^cargo run'
    end, result)

    if #targets == 0 then
      vim.notify('No runnable targets found at cursor position', vim.log.levels.WARN)
      return
    end

    if #targets == 1 then
      callback(targets[1])
    else
      vim.ui.select(targets, {
        prompt = 'Select runnable:',
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

--- Build the binary without running and parse JSON output to find the executable path.
--- Handles both test (`--no-run`) and run (replace with `build`) runnables.
--- Calls callback(executable_path) on success, or notifies on failure.
---@param args table
---@param callback fun(executable: string)
local function discover_binary(args, callback)
  local extra_args = { '--message-format=json' }
  if args.cargoArgs[1] == 'run' then
    args = vim.deepcopy(args)
    args.cargoArgs[1] = 'build'
  else
    table.insert(extra_args, 1, '--no-run')
  end
  local cmd = build_cargo_cmd(args, extra_args)

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

local function expand_macro(err, result)
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
end

local function run_runnable(runnable)
  local cmd = build_cargo_cmd(runnable.args)
  local is_test = runnable.label:match '^test ' or runnable.label:match '^doctest'

  vim.cmd 'split'
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, term_buf)
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = runnable.args.workspaceRoot,
    on_exit = function(_, exit_code)
      if is_test then
        if exit_code == 0 then
          vim.notify('Test passed: ' .. runnable.label, vim.log.levels.INFO)
        else
          vim.notify('Test failed: ' .. runnable.label, vim.log.levels.ERROR)
        end
      else
        if exit_code == 0 then
          vim.notify('Finished: ' .. runnable.label, vim.log.levels.INFO)
        else
          vim.notify('Exited with code ' .. exit_code .. ': ' .. runnable.label, vim.log.levels.ERROR)
        end
      end
    end,
  })
end

local function debug_runnable(runnable)
  vim.notify('Building binary...', vim.log.levels.INFO)

  discover_binary(runnable.args, function(executable)
    local run_args = {}
    if runnable.args.executableArgs and #runnable.args.executableArgs > 0 then
      vim.list_extend(run_args, runnable.args.executableArgs)
    end

    local dap = require 'dap'
    dap.run {
      type = 'codelldb',
      request = 'launch',
      name = 'Debug: ' .. runnable.label,
      program = executable,
      args = run_args,
      cwd = runnable.args.workspaceRoot,
      stopOnEntry = false,
    }
  end)
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
    send_request('rust-analyzer/expandMacro', expand_macro)
  end, '[R]ust [E]xpand Macro')

  map('<leader>rr', function()
    get_runnable(run_runnable)
  end, '[R]ust [R]un')

  map('<leader>rd', function()
    get_runnable(debug_runnable)
  end, '[R]ust [D]ebug')
end

return M
