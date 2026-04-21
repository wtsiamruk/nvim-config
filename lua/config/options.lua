-- Basics
vim.opt.number = true
vim.opt.numberwidth = 2
vim.opt.signcolumn = 'yes'
vim.opt.wrap = true
vim.opt.scrolloff = 15
vim.opt.sidescrolloff = 4

-- Tabs/spaces
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.breakindent = true

-- General Behaviours
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.backup = false --disable annoying vim file cache
vim.opt.clipboard = 'unnamedplus' --copy to system buffer
vim.opt.conceallevel = 0 --show concealed characters in markdown files
vim.opt.fileencoding = 'utf-8' --utf-8 obvisouly
vim.opt.mouse = 'a' -- enable mouse support
-- uncomment line below when the lua line plugin added, and if you'd like it
-- vim.opt.showmode = false:
-- Splits behaviour
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.termguicolors = true
vim.opt.timeoutlen = 1000 -- ms, timeout for the wait while typing a mapping/command
vim.opt.undofile = true

vim.opt.updatetime = 100 -- ms, completion
vim.opt.writebackup = false -- prevents editing files edited elsewhere
vim.opt.cursorline = true --current line highlight
vim.opt.cursorcolumn = true

-- Search Behaviour
vim.opt.hlsearch = true --highlight all search
vim.opt.ignorecase = true
vim.opt.smartcase = true
