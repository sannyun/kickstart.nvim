return {
  {
    'rcarriga/nvim-notify',
    config = function()
      vim.notify = require 'notify'
      local notify = require 'notify'

      vim.keymap.set('n', '<leader>nd', function()
        notify.dismiss { pending = true, silent = false }
      end, { desc = '[N]otify [D]ismiss' })
    end,
  },
}
