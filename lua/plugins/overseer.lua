return {
  {
    'stevearc/overseer.nvim',
    version = '1.6.0',
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
      { '<leader>or', '<cmd>OverseerRun<cr>', desc = '[O]verseer [R]un a task from a template' },
      { '<leader>ot', '<cmd>OverseerToggle<cr>', desc = '[O]verseer [T]oggle the task list' },
      {
        '<leader>ot',
        function()
          require('overseer').toggle { direction = 'left' }
        end,
        desc = '[O]verseer [T]oggle the task list',
      },
    },
  },
}
