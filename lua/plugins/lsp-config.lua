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
  ft = "java",
  dependencies = {
    "mfussenegger/nvim-dap",
  },
  config = function()
    local jdtls = require("jdtls")
    local cfg   = require("config.jdtls")
    local INFO  = vim.log.levels.INFO

    local function on_attach(_, bufnr)
      vim.notify("jdtls: attached", INFO)

      jdtls.dap.setup_dap({ hotcodereplace = "auto" })
      jdtls.dap.setup_dap_main_class_configs()

      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      map("n", "<leader>ji", jdtls.organize_imports,                          "[J]ava Organ[i]ze Imports")
      map("n", "<leader>jv", jdtls.extract_variable,                          "[J]ava Extract [V]ariable")
      map("n", "<leader>jV", jdtls.extract_variable_all,                      "[J]ava Extract [V]ariable (all)")
      map("v", "<leader>jm", function() jdtls.extract_method({ visual = true }) end, "[J]ava Extract [M]ethod")
      map("n", "<leader>jc", jdtls.extract_constant,                          "[J]ava Extract [C]onstant")
      map("n", "<leader>js", jdtls.super_implementation,                      "[J]ava Go to [S]uper")
      map("n", "<leader>jb", function() jdtls.compile("incremental") end,     "[J]ava [B]uild (incremental)")
      map("n", "<leader>jB", function() jdtls.compile("full") end,            "[J]ava [B]uild Full")
      map("n", "<leader>jU", jdtls.update_project_config,                     "[J]ava [U]pdate Build Config")
      map("n", "<leader>jt", jdtls.dap.test_nearest_method,                   "[J]ava [T]est Nearest Method")
      map("n", "<leader>jT", jdtls.dap.test_class,                            "[J]ava [T]est Class")
      map("n", "<leader>jP", jdtls.dap.pick_test,                             "[J]ava [P]ick Test")
    end

    local handlers = {
      ["language/status"] = function(_, result)
        if result.type == "ServiceReady" then
          vim.notify("jdtls: workspace ready", INFO)
        end
      end,
    }

    local function on_attach_syntax(_, _)
      vim.notify("jdtls: syntax server ready", INFO)
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = function()
        -- Walk up from the current file looking for the topmost pom.xml or
        -- build.gradle. This correctly handles Maven/Gradle multi-module layouts:
        -- we keep ascending as long as we keep finding build files, stopping at
        -- the highest ancestor that still has one — that is the project root.
        local path = vim.fn.expand("%:p:h")
        local root_dir = nil

        for dir in vim.fs.parents(path) do
          if vim.uv.fs_stat(dir .. "/pom.xml") or vim.uv.fs_stat(dir .. "/build.gradle") then
            root_dir = dir
          end
        end

        if not root_dir then
          -- No build file anywhere above — use the file's directory as a
          -- best-effort root for syntax-only mode.
          root_dir = vim.fn.expand("%:p:h")
          local project_name = vim.fn.fnamemodify(root_dir, ":t")
          local workspace_dir = vim.fn.expand("~/.local/share/nvim/jdtls-workspace/") .. project_name
          vim.notify("jdtls: no build files found, starting syntax-only…", INFO)
          local config = cfg.make_syntax_config(root_dir, workspace_dir)
          config.on_attach = on_attach_syntax
          config.handlers = handlers
          jdtls.start_or_attach(config)
          return
        end

        local project_name = vim.fn.fnamemodify(root_dir, ":t")
        local workspace_dir = vim.fn.expand("~/.local/share/nvim/jdtls-workspace/") .. project_name

        vim.notify("jdtls: starting (root: " .. project_name .. ")…", INFO)
        local config = cfg.make_standard_config(root_dir, workspace_dir, on_attach)
        config.handlers = handlers
        jdtls.start_or_attach(config)
      end,
    })

    vim.api.nvim_create_user_command("JavaCleanWorkspace", function()
      local clients = vim.lsp.get_clients({ name = "jdtls" })
      if #clients == 0 then
        vim.notify("jdtls: no active client", vim.log.levels.WARN)
        return
      end
      vim.lsp.buf.execute_command({ command = "java.clean.workspace" })
    end, { desc = "Clean jdtls workspace index" })
  end,
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
