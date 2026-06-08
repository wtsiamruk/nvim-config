return {
    "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000,
    config = function()
        --- color scheme setup
        require("catppuccin").setup({
            flavour = "auto", -- latte, frappe, macchiato, mocha
            background = { -- :h background
                light = "latte",
                dark = "mocha",
            }
        })
        vim.cmd.colorscheme "catppuccin-nvim"
    end

}

