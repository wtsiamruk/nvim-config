local mason_conf = {
    "mason-org/mason.nvim",
    config = function()
      require("mason").setup()
    end
}

local mason_lsp_conf = {
    "mason-org/mason-lspconfig.nvim",
    opts = {},
    dependencies = {
        "mason-org/mason.nvim",
        "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {"lua_ls", "rust_analyzer", "ts_ls","jdtls"},
      })
    end
}

local nvim_jdtls_conf = {
  "mfussenegger/nvim-jdtls",
  dependencies = {
    "mfussenegger/nvim-dap",
  }
}

local lsp_conf = {
  "neovim/nvim-lspconfig",
  config = function()
    local lspconf = vim.lsp.config
    local lsp = vim.lsp


    lsp.enable('lua_ls')

    lsp.enable('ts_ls')

    vim.keymap.set("n", "<leader>co", vim.lsp.buf.hover, { desc = "[C]ode Hover D[o]cumentation" })
    vim.keymap.set("n", "<leader>cg", vim.lsp.buf.definition, { desc = "[C]ode [G]oto Defintion" })
    vim.keymap.set("n", "<leader>cr", require("telescope.builtin").lsp_references, { desc = "[C]ode Show [R]eferences" })
    vim.keymap.set("n", "<leader>ci", require("telescope.builtin").lsp_implementations, { desc = "[C]ode Show [I]mplementations" })
    vim.keymap.set({"n","v"}, "<leader>ca", vim.lsp.buf.code_action, { desc = "Show [C]ode [A]ctions" })
    vim.keymap.set("n", "<leader>cR", vim.lsp.buf.rename, { desc = "[C]ode [R]ename"})
    vim.keymap.set("n", "<leader>cD", vim.lsp.buf.declaration, { desc = "[C]ode [D]eclaration"})



  end
}




local parent = {
  mason_conf, mason_lsp_conf, nvim_jdtls_conf,lsp_conf
}



return parent
