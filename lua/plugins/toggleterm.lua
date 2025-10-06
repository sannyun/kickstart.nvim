local function get_term_index(current_id, terms)
  local idx
  for i, v in ipairs(terms) do
    if v.id == current_id then
      idx = i
    end
  end
  return idx
end

local function go_prev_term()
  local current_id = vim.b.toggle_number
  if current_id == nil then
    return
  end

  local terms = require('toggleterm.terminal').get_all(true)
  local prev_index

  local index = get_term_index(current_id, terms)
  if index > 1 then
    prev_index = index - 1
  else
    prev_index = #terms
  end

  require('toggleterm').toggle(terms[index].id)
  require('toggleterm').toggle(terms[prev_index].id)
end

local function go_next_term()
  local current_id = vim.b.toggle_number
  if current_id == nil then
    return
  end

  local terms = require('toggleterm.terminal').get_all(true)
  local next_index

  local index = get_term_index(current_id, terms)
  if index == #terms then
    next_index = 1
  else
    next_index = index + 1
  end

  require('toggleterm').toggle(terms[index].id)
  require('toggleterm').toggle(terms[next_index].id)
end

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
        persist_size = false,
      }

      vim.keymap.set('n', '<leader>ttn', ':TermNew<cr>', { desc = '[T]oggle[T]erm [N]ew' })

      vim.keymap.set('n', '<leader>tts', function()
        local has_open, windows = require('toggleterm.ui').find_open_windows()
        if has_open then
          require('toggleterm.ui').close_and_save_terminal_view(windows)
        end

        vim.api.nvim_cmd({ cmd = 'TermSelect' }, {})
      end, { desc = '[T]oggle[T]erm [S]elect' })

      vim.keymap.set('n', '<leader>tth', ':ToggleTerm<cr>:ToggleTerm direction=horizontal<cr>', { desc = '[T]oggle[T]erm [H]orizontal' })
      vim.keymap.set('n', '<leader>ttv', ':ToggleTerm<cr>:ToggleTerm direction=vertical<cr>', { desc = '[T]oggle[T]erm [V]ertical' })
      vim.keymap.set('n', '<leader>ttf', ':ToggleTerm<cr>:ToggleTerm direction=float<cr>', { desc = '[T]oggle[T]erm [F]loat' })

      vim.keymap.set({ 'n', 't' }, '<F9>', '<cmd>ToggleTerm<cr>', { desc = 'Toggle Term' })

      vim.keymap.set({ 'n', 't' }, '<F8>', function()
        go_next_term()
      end, { desc = 'Toggle Term' })

      vim.keymap.set({ 'n', 't' }, '<F7>', function()
        go_prev_term()
      end, { desc = 'Toggle Term' })
    end,
  },
}
