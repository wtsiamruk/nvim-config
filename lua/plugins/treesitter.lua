conf = {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  dependencies = {
    "windwp/nvim-ts-autotag"
  },
  config = function()
    -- my config here
    local treeSitterPath = vim.fn.stdpath('data') .. '/treesitter'
    local nvim_treesitter = require('nvim-treesitter')
    nvim_treesitter.setup({
      install_dir = treeSitterPath
    })
    vim.opt.rtp:prepend(treeSitterPath)
    nvim_treesitter.install({
       'rust','cpp', 'java','kotlin','javascript','typescript', 'tsx','python','sql','html', 'xml','vim','vimdoc','lua','markdown','markdown_inline','gitignore'
    })
    vim.api.nvim_create_autocmd('FileType' , {
      pattern = {'rust','cpp', 'java','kotlin','javascript','typescript', 'tsx','python','sql','html', 'xml','vim','vimdoc','lua','markdown','markdown_inline','gitignore'},
      callback = function()
        vim.treesitter.start()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })

  end
}



return conf;
