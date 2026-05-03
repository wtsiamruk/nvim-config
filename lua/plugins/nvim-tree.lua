return {
    "nvim-tree/nvim-tree.lua",
    version = "1.16.0", tag = "v1.16.0",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        vim.keymap.set("n", "<leader>e","<cmd>NvimTreeToggle<CR>", { desc = "Toggle File Tree [E]xplorer"})
        require("nvim-tree").setup({
            hijack_netrw = true,
            auto_reload_on_write = true,
            git = {
                ignore = false,
            },
            view = {
                preserve_window_proportions = true,
                 side = "left",
                 width = 50
            }
        })
    end,
}
