return {
  {
    'theHamsta/nvim-dap-virtual-text',
    config = true,
    dependencies = {
      'mfussenegger/nvim-dap',
    },
  },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'
      dapui.setup()

      dap.listeners.after.event_initialized['dapui_config'] = function()
        dapui.open {}
      end
      dap.listeners.before.event_terminated['dapui_config'] = function()
        dapui.close {}
      end

      vim.keymap.set('n', '<leader>dd', function()
        dapui.toggle()
      end)
    end,
  },
  {
    'mfussenegger/nvim-dap',
    dependencies = 'williamboman/mason.nvim',
    config = function()
      local dap = require 'dap'

      -- dap.set_log_level 'TRACE'
      -- dap.adapters.codelldb = {
      --   type = 'executable',
      --   command = vim.fn.exepath 'codelldb',
      --
      --   -- On windows you may have to uncomment this:
      --   detached = false,
      -- }

      dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
          command = vim.fn.exepath 'codelldb',
          args = { '--port', '${port}' },
        },

        -- On windows you may have to uncomment this:
        detached = false,
      }

      dap.configurations.cpp = {
        {
          name = 'Launch file',
          type = 'codelldb',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          cwd = '${workspaceFolder}/build/Debug',
          stopOnEntry = false,
        },
      }

      dap.configurations.rust = {
        {
          name = 'Launch file',
          type = 'codelldb',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
        },
      }
    end,
    keys = {
      { '<leader>dc', '<cmd>DapContinue<cr>', desc = 'DAP [C]ontinue' },
      { '<leader>db', '<cmd>DapToggleBreakpoint<cr>', desc = 'DAP Toggle [b]reakpoint' },
      { '<leader>dt', '<cmd>DapTerminate<cr>', desc = 'DAP [T]erminate' },
    },
  },
  {
    'lucaSartore/nvim-dap-exception-breakpoints',
    dependencies = { 'mfussenegger/nvim-dap' },

    config = function()
      local set_exception_breakpoints = require 'nvim-dap-exception-breakpoints'

      vim.api.nvim_set_keymap('n', '<leader>de', '', { desc = '[D]ebug [C]ondition breakpoints', callback = set_exception_breakpoints })
    end,
  },
}
