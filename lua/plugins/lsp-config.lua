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
        -- jdtls must be in ensure_installed so mason installs it on new machines.
        -- automatic_enable excludes it so lspconfig does NOT auto-start it —
        -- nvim-jdtls manages the jdtls lifecycle via its own FileType autocmd.
        ensure_installed = {"lua_ls", "rust_analyzer", "ts_ls", "jdtls", "clangd", "sourcekit-lsp", "groovyls"},
        automatic_enable = {
          exclude = { "jdtls" },
        },
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

      if jdtls.dap then
        jdtls.dap.setup_dap({ hotcodereplace = "auto" })
        jdtls.dap.setup_dap_main_class_configs()

        -- ── Manual launch config (no auto-detected main) ──────────────────────
        -- setup_dap_main_class_configs() scans source files for classes with a
        -- literal main() method and registers a DAP launch config for each one.
        -- If your project has no discoverable main — e.g. a library module, or
        -- you want to launch a specific class that jdtls missed — uncomment the
        -- block below and fill in mainClass and projectName.
        --
        -- HOW TO USE:
        --   1. Set mainClass to the fully-qualified class name, e.g.:
        --        mainClass = "com.example.MyApp"
        --   2. Set projectName to the Eclipse project name jdtls assigned.
        --      You can find it by running:
        --        :lua print(vim.lsp.get_active_clients()[1].config.root_dir)
        --      and matching it to what jdtls reports in :LspLog on import.
        --   3. Uncomment the block, save, and re-open a Java file to re-trigger
        --      on_attach (or :e to reload the buffer).
        --   4. Run :DapContinue — your config appears in the picker alongside
        --      any auto-detected main classes.
        --
        -- table.insert(require("dap").configurations.java, {
        --   type        = "java",
        --   request     = "launch",
        --   name        = "Launch MyApp (manual)",
        --   mainClass   = "com.example.MyApp",
        --   projectName = "my-project",
        --   -- classPaths and modulePaths are optional: jdtls resolves them from
        --   -- the workspace index when left empty.
        --   classPaths  = {},
        --   modulePaths = {},
        -- })

        -- ── Remote / attach config ────────────────────────────────────────────
        -- Use this when the JVM is already running externally (local Docker
        -- container, a remote server, or a Spring Boot app started outside Neovim)
        -- and you want to attach the debugger to it without launching a new process.
        --
        -- STEP 1 — start your JVM with JDWP enabled:
        --   java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -jar myapp.jar
        --
        --   suspend=n  → JVM starts immediately; attach at any time after boot.
        --   suspend=y  → JVM pauses at startup and waits for a debugger to attach
        --               before executing any code. Use this if you need to hit a
        --               breakpoint in a static initialiser, @PostConstruct, or
        --               any code that runs before the first HTTP request.
        --
        -- STEP 2 — uncomment the block below, set hostName and port to match,
        --          then re-open a Java buffer to re-trigger on_attach.
        --
        -- STEP 3 — run :DapContinue. The picker shows this entry; selecting it
        --          connects nvim-dap to the running JVM via JDWP. Breakpoints
        --          you set in Neovim will suspend the remote process in-place.
        --
        -- NOTE: the remote JVM and Neovim must agree on source paths. If jdtls
        -- has the project open (i.e. you opened a source file from that project),
        -- source mapping is automatic. For a fully remote machine you may need to
        -- mount the source tree or configure sourceContainers.
        --
        -- table.insert(require("dap").configurations.java, {
        --   type     = "java",
        --   request  = "attach",
        --   name     = "Attach remote (localhost:5005)",
        --   hostName = "localhost",   -- replace with remote IP/hostname if needed
        --   port     = 5005,
        -- })
      else
        vim.notify(
          "jdtls: debugging unavailable — install DAP jars via :MasonInstall java-debug-adapter java-test",
          vim.log.levels.WARN
        )
      end

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
      map("n", "<leader>jf", function()
        require("telescope.builtin").lsp_dynamic_workspace_symbols()
      end,                                                                       "[J]ava [F]ind in Classpath")
      map("n", "<leader>jS", function()
        require("telescope.builtin").live_grep({
          search_dirs = { vim.fn.stdpath("data") .. "/lazy/nvim-jdtls" },
          prompt_title = "Search nvim-jdtls source",
        })
      end,                                                                       "[J]dtls plugin [S]ource grep")
      if jdtls.dap then
        map("n", "<leader>jt", jdtls.dap.test_nearest_method,                 "[J]ava [T]est Nearest Method")
        map("n", "<leader>jT", jdtls.dap.test_class,                          "[J]ava [T]est Class")
        map("n", "<leader>jP", jdtls.dap.pick_test,                           "[J]ava [P]ick Test")
      end
    end

    local handlers = {
      ["language/status"] = function(_, result)
        if result.type == "ServiceReady" then
          vim.notify("jdtls: workspace ready", INFO)
        end
      end,
      ["textDocument/definition"] = function(err, result, ctx, config)
        require("jdtls").open_classfile(err, result, ctx, config)
      end,
    }

    local function on_attach_syntax(_, _)
      vim.notify("jdtls: syntax server ready", INFO)
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = function()
        -- jdt:// buffers are decompiled class files opened by jdtls — they are
        -- not real files on disk and must not trigger a new server start.
        if vim.startswith(vim.api.nvim_buf_get_name(0), "jdt://") then
          return
        end

        -- Walk up from the current file looking for the topmost build file.
        -- Maven: pom.xml at every module level — topmost wins.
        -- Gradle Groovy DSL: build.gradle / settings.gradle / gradlew.
        -- Gradle Kotlin DSL: build.gradle.kts / settings.gradle.kts.
        -- Gradle multi-module roots often have only settings.gradle(.kts) or
        -- gradlew at the top with no build.gradle there — all are valid anchors.
        local path = vim.fn.expand("%:p:h")
        local root_dir = nil

        for dir in vim.fs.parents(path) do
          if vim.uv.fs_stat(dir .. "/pom.xml")
            or vim.uv.fs_stat(dir .. "/build.gradle")
            or vim.uv.fs_stat(dir .. "/build.gradle.kts")
            or vim.uv.fs_stat(dir .. "/settings.gradle")
            or vim.uv.fs_stat(dir .. "/settings.gradle.kts")
            or vim.uv.fs_stat(dir .. "/gradlew")
          then
            root_dir = dir
          end
        end

        -- Already attached for this root — skip re-running the full config.
        local clients = vim.lsp.get_clients({ name = "jdtls" })
        for _, client in ipairs(clients) do
          if client.root_dir == root_dir then
            return
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
        local build_system_file = workspace_dir .. "/build-system"

        local function start_jdtls(build_system)
          -- Persist the choice so the picker is skipped on subsequent opens.
          vim.fn.mkdir(workspace_dir, "p")
          local f = io.open(build_system_file, "w")
          if f then f:write(build_system) f:close() end

          if build_system == "Syntax" then
            vim.notify("jdtls: starting syntax-only (root: " .. project_name .. ")…", INFO)
            local config = cfg.make_syntax_config(root_dir, workspace_dir)
            config.on_attach = on_attach_syntax
            config.handlers  = handlers
            jdtls.start_or_attach(config)
            return
          end

          local overrides = {}
          if build_system == "Maven" then
            overrides.maven_enabled  = true
            overrides.gradle_enabled = false
          elseif build_system == "Gradle" then
            overrides.maven_enabled  = false
            overrides.gradle_enabled = true
          end
          vim.notify("jdtls: starting " .. build_system .. " (root: " .. project_name .. ")…", INFO)
          local config = cfg.make_standard_config(root_dir, workspace_dir, on_attach, overrides)
          config.handlers = handlers
          jdtls.start_or_attach(config)
        end

        -- If the user already chose a build system for this project, use it.
        local persisted_f = io.open(build_system_file, "r")
        if persisted_f then
          local choice = persisted_f:read("*l")
          persisted_f:close()
          if choice and choice ~= "" then
            start_jdtls(choice)
            return
          end
        end

        -- Build the option list from what is actually present on disk.
        local has_maven = vim.uv.fs_stat(root_dir .. "/pom.xml")
          or vim.uv.fs_stat(root_dir .. "/mvnw")
        local has_gradle = vim.uv.fs_stat(root_dir .. "/build.gradle")
          or vim.uv.fs_stat(root_dir .. "/build.gradle.kts")
          or vim.uv.fs_stat(root_dir .. "/settings.gradle")
          or vim.uv.fs_stat(root_dir .. "/settings.gradle.kts")
          or vim.uv.fs_stat(root_dir .. "/gradlew")

        local options = {}
        if has_maven  then table.insert(options, "Maven")  end
        if has_gradle then table.insert(options, "Gradle") end
        table.insert(options, "Syntax")

        vim.schedule(function()
          vim.ui.select(options, {
            prompt = "jdtls — select build system for " .. project_name .. ":",
          }, function(choice)
            if not choice then return end
            start_jdtls(choice)
          end)
        end)
      end,
    })

    vim.api.nvim_create_user_command("JavaCleanWorkspace", function()
      local clients = vim.lsp.get_clients({ name = "jdtls" })
      if #clients == 0 then
        vim.notify("jdtls: no active client", vim.log.levels.WARN)
        return
      end
      -- java.clean.workspace triggers a workspace wipe + automatic server
      -- restart inside jdtls. Use the client directly — vim.lsp.buf.execute_command
      -- is deprecated in Neovim 0.12.
      clients[1]:exec_command({ command = "java.clean.workspace" })
    end, { desc = "Clean jdtls workspace index" })

    -- Delete the persisted build-system choice for the current project so the
    -- picker is shown again on the next Java file open.
    vim.api.nvim_create_user_command("JavaResetBuildSystem", function()
      local clients = vim.lsp.get_clients({ name = "jdtls" })
      local root_dir
      if #clients > 0 then
        root_dir = clients[1].root_dir
      else
        root_dir = vim.fn.expand("%:p:h")
      end
      local project_name   = vim.fn.fnamemodify(root_dir, ":t")
      local workspace_dir  = vim.fn.expand("~/.local/share/nvim/jdtls-workspace/") .. project_name
      local build_sys_file = workspace_dir .. "/build-system"
      if vim.uv.fs_stat(build_sys_file) then
        vim.uv.fs_unlink(build_sys_file, function() end)
        vim.notify("jdtls: build-system choice cleared for " .. project_name .. " — reopen a Java file to pick again", vim.log.levels.INFO)
      else
        vim.notify("jdtls: no persisted build-system choice for " .. project_name, vim.log.levels.WARN)
      end
      -- Stop the running client so the next open triggers a fresh start.
      for _, client in ipairs(clients) do
        client.stop()
      end
    end, { desc = "Reset jdtls build system choice and restart" })
  end,
}

local lsp_conf = {
  "neovim/nvim-lspconfig",
  config = function()
    local lspconf = vim.lsp.config
    local lsp = vim.lsp


    lsp.enable('lua_ls')

    lsp.enable('ts_ls')
 
    -- 1. Configure the servers (merges with defaults from nvim-lspconfig)
    vim.lsp.config("clangd", {
      cmd = { "clangd", "--background-index", "--clang-tidy" },
      filetypes = { "c", "cpp", "objc", "objcpp" },
    })
    lsp.enable('clangd')


    -- Explicitly disabled: jdtls is managed entirely by nvim-jdtls (see
    -- nvim_jdtls_conf above). lspconfig must not auto-start it.
    vim.lsp.config('jdtls', { autostart = false })

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
