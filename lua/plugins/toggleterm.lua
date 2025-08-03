return {
  {
    'akinsho/toggleterm.nvim',
    config = function()
      require('toggleterm').setup {
        size = function(term)
          if term.direction == 'horizontal' then
            return 20
          elseif term.direction == 'vertical' then
            return vim.o.columns - vim.o.colorcolumn
          end
        end,

        open_mapping = [[<C-\>]],
        direction = 'horizontal',
        float_opt = {
          border = 'curved',
        },
        winbar = {
          enabled = true,
          name_formatter = function(term) --  term: Terminal
            return term.name
          end,
        },
        close_on_exit = false,
        persist_mode = true,
      }

      vim.keymap.set('n', '<leader>ttn', ':TermNew<cr>', { desc = '[T]oggle[T]erm [N]ew' })
      vim.keymap.set('n', '<leader>tts', ':TermSelect<cr>', { desc = '[T]oggle[T]erm [S]elect' })
      vim.keymap.set('n', '<leader>tth', ':ToggleTerm<cr>:ToggleTerm direction=horizontal<cr>', { desc = '[T]oggle[T]erm [H]orizontal' })
      vim.keymap.set('n', '<leader>ttv', ':ToggleTerm<cr>:ToggleTerm direction=vertical<cr>', { desc = '[T]oggle[T]erm [V]ertical' })
      vim.keymap.set('n', '<leader>ttf', ':ToggleTerm<cr>:ToggleTerm direction=float<cr>', { desc = '[T]oggle[T]erm [F]loat' })
    end,
  },
}
