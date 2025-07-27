return {
  {
    'akinsho/toggleterm.nvim',
    config = function()
      require('toggleterm').setup {
        open_mapping = [[<C-\>]],
        direction = 'float',
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
      }
    end,
    keys = {
      { '<leader>tn', '<cmd>TermNew<cr>', desc = '[T]oggleTerm [N]ew' },
      { '<leader>ts', '<cmd>TermSelect<cr>', desc = '[T]oggleTerm [S]elect' },
    },
  },
}
