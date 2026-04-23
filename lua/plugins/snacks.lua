local snacks_plugin = {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    lazygit  = {},
    terminal = {},
    scroll   = { enabled = true },
    animate  = {},
    notifier = { enabled = true, top_down = false, margin = { bottom = 7, right = 3 } },
  },
  keys = {
    -- Option+F7 in kitty sends <F55> (kitty keyboard protocol encoding)
    { "<F55>",  function() Snacks.lazygit.open() end, desc = "Launch lazygit" },
    { "<A-`>",  function() Snacks.terminal() end,     desc = "Toggle terminal" },
  },
}
return snacks_plugin
