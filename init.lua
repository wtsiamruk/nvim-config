-- declare the path where lazy will clone the plugin code
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "git@github.com:folke/lazy.nvim.git",
    "--branch=stable", --latest stable release
    lazypath
  })
end

-- add the lazypath into vim runtime path
vim.opt.rtp:prepend(lazypath)

local opts = {
  change_detection = {
    notify = false --not notify on every change
  },
  checker = { --check but not notify on each update
    enabled = true,
    notify = false
  }
}


require("config.options")
require("config.keymaps")


-- Lazy setup, always should be last in the config
require("lazy").setup("plugins", opts)

--- color scheme setup
require("catppuccin").setup({
  flavour = "mocha"
})
vim.cmd.colorscheme "catppuccin-nvim"

