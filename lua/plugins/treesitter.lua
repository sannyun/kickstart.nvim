-- Highlight, edit, and navigate code

return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  branch = 'main',
  -- [[ Configure Treesitter ]] See `:help nvim-treesitter-intro`
  config = function()
    local parsers = { 'bash', 'c', 'cpp', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'rust', 'zig' }
    require('nvim-treesitter').install(parsers)

    vim.api.nvim_create_autocmd('FileType', {
      pattern = parsers,
      callback = function()
        -- enables syntax highlighting and other treesitter features
        vim.treesitter.start()

        -- enables treesitter based folds
        -- for more info on folds see `:help folds`
        -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

        -- enables treesitter based indentation
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
  -- There are additional nvim-treesitter modules that you can use to interact
  -- with nvim-treesitter. You should go explore a few and see what interests you:
  --
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  -- - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects (using the `main` branch)
}
