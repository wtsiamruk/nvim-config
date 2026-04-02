conf = {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    -- my config here
    treeSitterPath = vim.fn.stdpath('data') .. '/treesitter'
    require('nvim-treesitter').setup({
      install_dir = treeSitterPath
    })
    vim.opt.rtp:prepend(treeSitterPath)
    require('nvim-treesitter').install({
      'rust','cpp', 'java','kotlin','javascript','typescript', 'tsx','python','sql','html'
    })

  end
}



return conf;
