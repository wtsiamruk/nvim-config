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
        local servers = {
            "lua_ls",
            "rust_analyzer",
            "ts_ls",
            "clangd",
            "groovyls",
            -- Java: jdtls is driven by the nvim-jdtls plugin spec below
            -- (not nvim-lspconfig), with the heavy config in
            -- lua/config/jdtls.lua. Mason still installs the launcher,
            -- lombok agent, and Eclipse config dirs here.
            -- "jdtls",
        }

        require("mason-lspconfig").setup({
            ensure_installed = servers,
            -- jdtls is started by nvim-jdtls; don't let mason-lspconfig
            -- also auto-enable it via lspconfig.
            automatic_enable = { exclude = { "jdtls" } },
        })

        -- Auxiliary tools used by the Java stack (DAP + test runner).
        local ok_mr, mr = pcall(require, "mason-registry")
        if ok_mr then
            for _, name in ipairs({ "java-debug-adapter", "java-test" }) do
                local ok_pkg, pkg = pcall(mr.get_package, name)
                if ok_pkg and not pkg:is_installed() then
                    pkg:install()
                end
            end
        end
    end
}


local lsp_conf = {
    "neovim/nvim-lspconfig",
    config = function()
        -- Languages
        local lsp = vim.lsp

        lsp.enable('lua_ls')

        lsp.enable('ts_ls')

        -- 1. Configure the servers (merges with defaults from nvim-lspconfig)
        lsp.config("clangd", {
            cmd = { "clangd", "--background-index", "--clang-tidy" },
            filetypes = { "c", "cpp", "objc", "objcpp" },
        })
        lsp.enable('clangd')




        -- keymaps

        -- These GLOBAL keymaps are created unconditionally when Nvim starts:
        --
        -- - "gra" (Normal and Visual mode) is mapped to |vim.lsp.buf.code_action()|
        -- - "gri" is mapped to |vim.lsp.buf.implementation()|
        -- - "grn" is mapped to |vim.lsp.buf.rename()|
        -- - "grr" is mapped to |vim.lsp.buf.references()|
        -- - "grt" is mapped to |vim.lsp.buf.type_definition()|
        -- - "grx" is mapped to |vim.lsp.codelens.run()|
        -- - "gO" is mapped to |vim.lsp.buf.document_symbol()|
        -- - CTRL-S (Insert mode) is mapped to |vim.lsp.buf.signature_help()|
        -- - |v_an| and |v_in| fall back to LSP |vim.lsp.buf.selection_range()| if
        --   treesitter is not active.
        -- - |gx| handles `textDocument/documentLink`. Example: with gopls, invoking gx
        --   on "os" in this Go code will open documentation externally: >
        --     package nvim
        --     import (
        --        "os"
        --     )
        --
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', 'grr', builtin.lsp_references, {desc = 'Find References'})


    end
}




-- Java (Eclipse JDT.LS) — plugin spec stays here next to the other LSPs;
-- all the heavy lifting (cmd, JVM flags, bundles, settings, on_attach,
-- workspace placement, decompiler) lives in lua/config/jdtls.lua.
local jdtls_conf = {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
        "neovim/nvim-lspconfig",
        "hrsh7th/cmp-nvim-lsp",
        "mfussenegger/nvim-dap",
        "mason-org/mason.nvim",
    },
    config = function()
        require("config.jdtls").setup()
    end,
}


local parent = {
    mason_conf, mason_lsp_conf, lsp_conf, jdtls_conf
}



return parent
