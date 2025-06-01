return {
  {
    'saecki/crates.nvim',
    tag = 'stable',
    config = function()
      require('crates').setup {}
    end,
  },
  {
    'stevearc/overseer.nvim',
    config = function()
      require('overseer').setup {
        strategy = {
          'toggleterm',
          use_shell = true,
          quit_on_exit = 'never',
          close_on_exit = false,
        },
      }
    end,

    keys = {
      { '<leader>or', '<cmd>OverseerRun<cr>', desc = '[O]verseer [r]un a task from a template' },
      { '<leader>ot', '<cmd>OverseerToggle<cr>', desc = '[O]verseer [t]oggle the task list' },
    },
  },
  {
    'akinsho/toggleterm.nvim',
    config = function()
      require('toggleterm').setup {
        open_mapping = [[<c-\>]],
        close_on_exit = false,
      }
    end,
  },
}
