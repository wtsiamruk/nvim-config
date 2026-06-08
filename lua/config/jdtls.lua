-- Eclipse JDT.LS configuration, driven from the nvim-jdtls plugin spec in
-- lua/plugins/lsp-config.lua. Lives here (lua/config/) so the language-
-- specific tuning sits next to other per-category config modules, the way
-- an IDE separates "Java settings" from "plugin install" panels.
--
-- Tuned for very large projects (Elasticsearch-scale Gradle monorepos).
-- Heavy debug instrumentation is on by default; flip DEBUG = false once happy.

local M = {}

local DEBUG = true

-- Local jdt.ls build (fork checkout). If a launcher jar lives under
-- <LOCAL_JDTLS>/plugins/, it wins over Mason. Override via $JDTLS_HOME.
local LOCAL_JDTLS = vim.env.JDTLS_HOME

function M.setup()
    -------------------------------------------------------------------------
    -- 0. Debug logging (first-startup troubleshooting)
    --    Scoped to jdtls only:
    --      * -Dlog.level=ALL + -Dlog.protocol=true (jdt.ls JVM, set in cmd)
    --      * java.trace.server = "verbose"           (jdt.ls init option)
    --    Both land in the per-project Eclipse workspace log, NOT in
    --    Neovim's global ~/.local/state/nvim/lsp.log. We deliberately do
    --    NOT call vim.lsp.set_log_level() — that would crank every other
    --    LSP's chattiness too.
    -------------------------------------------------------------------------
    if DEBUG then
        vim.notify(
            "[jdtls] debug logging is jdtls-only (Neovim LSP log level untouched)."
            .. "\nRun :JdtShowLogs to tail the Eclipse workspace log.",
            vim.log.levels.INFO
        )
    end

    -------------------------------------------------------------------------
    -- 1. Platform + jdt.ls install discovery
    --    Prefer LOCAL_JDTLS (a fork/local build); fall back to Mason.
    -------------------------------------------------------------------------
    local sys = vim.uv.os_uname().sysname
    local config_subdir =
        (sys == "Darwin" and "config_mac")
        or (sys == "Linux" and "config_linux")
        or (sys == "Windows_NT" and "config_win")
        or "config_linux"

    local mason_root  = vim.fn.stdpath("data") .. "/mason"
    local mason_jdtls = mason_root .. "/packages/jdtls"

    local function find_launcher(root)
        if not root or root == "" then return nil end
        local match = vim.fn.glob(root .. "/plugins/org.eclipse.equinox.launcher_*.jar")
        if match == "" then return nil end
        return { root = root, launcher = match }
    end

    local resolved =
        find_launcher(LOCAL_JDTLS)
        or find_launcher(mason_jdtls)

    assert(resolved,
        "[jdtls] launcher jar not found.\n"
        .. "  local: " .. LOCAL_JDTLS .. "/plugins/\n"
        .. "  mason: " .. mason_jdtls  .. "/plugins/\n"
        .. "Build your fork (mvn -o -B verify -DskipTests) or run :Mason and install 'jdtls'.")

    local jdtls_root   = resolved.root
    local launcher_jar = resolved.launcher
    local jdtls_config = jdtls_root .. "/" .. config_subdir
    local jdtls_source = (jdtls_root == LOCAL_JDTLS) and "local" or "mason"

    -- Lombok lives next to jdtls in Mason's package, but a local Eclipse
    -- build does NOT ship it. Search the resolved root, then Mason's
    -- package, then a user-managed dir; if nothing found, skip the
    -- -javaagent flag with a warning.
    local function find_lombok()
        for _, p in ipairs({
            jdtls_root  .. "/lombok.jar",
            mason_jdtls .. "/lombok.jar",
            vim.fn.stdpath("data") .. "/jdtls-bundles/lombok.jar",
        }) do
            if vim.uv.fs_stat(p) then return p end
        end
        return nil
    end
    local lombok_jar = find_lombok()
    if not lombok_jar then
        vim.notify(
            "[jdtls] lombok.jar not found — Lombok annotations won't be processed."
            .. "\n  Drop one at " .. vim.fn.stdpath("data")
            .. "/jdtls-bundles/lombok.jar to enable it.",
            vim.log.levels.WARN)
    end

    -------------------------------------------------------------------------
    -- 2. Project root + per-project workspace
    --    Eclipse metadata (.project, .classpath, .settings/) lives in the
    --    workspace dir, NOT in the project tree — see settings table below
    --    (java.import.generatesMetadataFilesAtProjectRoot).
    -------------------------------------------------------------------------
    local root_markers = {
        "gradlew", "mvnw",
        "build.gradle", "build.gradle.kts",
        "settings.gradle", "settings.gradle.kts",
        "pom.xml",
        ".git",
    }
    local root_dir = vim.fs.root(0, root_markers) or vim.fn.getcwd()
    local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")

    local workspace_dir =
        vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"
    local fresh_workspace = not vim.uv.fs_stat(workspace_dir .. "/.metadata")
    vim.fn.mkdir(workspace_dir, "p")

    -- One-time scrub on fresh imports: jdt.ls's filesystem virtualization
    -- only redirects metadata when the file doesn't already exist at the
    -- project root (see JLSFsUtils#shouldStoreInMetadataArea). If an
    -- earlier import (or another IDE) left .project etc. behind, jdt.ls
    -- silently keeps writing there even with the -D flag set. Wipe them
    -- before the first import for this workspace.
    if fresh_workspace then
        for _, name in ipairs({ ".project", ".classpath", ".factorypath", ".settings" }) do
            local p = root_dir .. "/" .. name
            if vim.uv.fs_stat(p) then
                vim.fn.delete(p, "rf")
                if DEBUG then
                    vim.notify("[jdtls] removed pre-existing " .. p
                        .. " (fresh workspace import)", vim.log.levels.INFO)
                end
            end
        end
    end

    -- Belt-and-braces: keep these names out of fuzzy finders / file
    -- completions if jdt.ls ever does write them (older versions, edge
    -- cases, or projects that already contain them).
    for _, pat in ipairs({
        ".project", ".classpath", ".factorypath",
        ".settings", ".settings/*",
        "bin/*", ".gradle/*", "build/*",
    }) do
        vim.opt.wildignore:append(pat)
    end

    if DEBUG then
        vim.notify(table.concat({
            "[jdtls] source       = " .. jdtls_source .. " (" .. jdtls_root .. ")",
            "[jdtls] root_dir     = " .. root_dir,
            "[jdtls] project      = " .. project_name,
            "[jdtls] workspace    = " .. workspace_dir,
            "[jdtls] config_dir   = " .. jdtls_config,
            "[jdtls] launcher_jar = " .. launcher_jar,
            "[jdtls] lombok_jar   = " .. (lombok_jar or "<none>"),
        }, "\n"), vim.log.levels.INFO)
    end

    -------------------------------------------------------------------------
    -- 3. DAP + test + decompiler bundles (mason)
    -------------------------------------------------------------------------
    local bundles = {}

    vim.list_extend(bundles, vim.fn.glob(
        mason_root .. "/share/java-debug-adapter/com.microsoft.java.debug.plugin-*.jar",
        true, true))

    local excluded = {
        ["com.microsoft.java.test.runner-jar-with-dependencies.jar"] = true,
        ["jacocoagent.jar"] = true,
    }
    for _, jar in ipairs(vim.fn.glob(
        mason_root .. "/share/java-test/*.jar", true, true)) do
        if not excluded[vim.fn.fnamemodify(jar, ":t")] then
            table.insert(bundles, jar)
        end
    end

    -- Decompiler bundle (dgileadi/vscode-java-decompiler). Mason doesn't
    -- ship this directly; drop the jar under
    --   $MASON/share/vscode-java-decompiler/*.jar
    -- or anywhere on disk and update the glob below. The settings table
    -- also sets contentProvider.preferred = "fernflower" so jdt.ls's
    -- built-in Fernflower kicks in even without this bundle.
    local decompiler_globs = {
        mason_root .. "/share/vscode-java-decompiler/*.jar",
        vim.fn.stdpath("data") .. "/jdtls-bundles/decompiler/*.jar",
    }
    for _, pat in ipairs(decompiler_globs) do
        vim.list_extend(bundles, vim.fn.glob(pat, true, true))
    end

    if DEBUG then
        vim.notify("[jdtls] bundles (" .. #bundles .. "):\n  "
            .. table.concat(bundles, "\n  "), vim.log.levels.INFO)
    end

    -------------------------------------------------------------------------
    -- 4. cmd: the raw java invocation
    --    Tuned for ~10k file Gradle projects (Elasticsearch-scale).
    -------------------------------------------------------------------------
    local cmd = {
        "java",

        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",

        "-Dlog.protocol=true",
        "-Dlog.level=" .. (DEBUG and "ALL" or "WARNING"),

        -- Keep .project/.classpath/.factorypath/.settings OUT of the
        -- project root. This is read as a JVM system property by
        -- JLSFsUtils, NOT from the LSP settings table — the equivalent
        -- java.import.* LSP setting is ignored. PR eclipse-jdtls#1900.
        "-Djava.import.generatesMetadataFilesAtProjectRoot=false",

        -- Heap. Bump -Xmx to 12g/16g if initial Gradle import OOMs.
        "-Xms4g",
        "-Xmx8g",
        "-XX:MaxMetaspaceSize=1g",
        "-XX:MaxDirectMemorySize=1g",

        "-XX:+UseG1GC",
        "-XX:+UseStringDeduplication",
        "-XX:GCTimeRatio=4",
        "-XX:AdaptiveSizePolicyWeight=90",
    }

    if lombok_jar then
        table.insert(cmd, "-javaagent:" .. lombok_jar)
    end

    vim.list_extend(cmd, {
        -- JPMS opens required by Eclipse JDT on JDK 16+.
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",

        "-jar", launcher_jar,
        "-configuration", jdtls_config,
        "-data",          workspace_dir,
    })

    -------------------------------------------------------------------------
    -- 5. capabilities
    -------------------------------------------------------------------------
    local capabilities = vim.tbl_deep_extend(
        "force",
        vim.lsp.protocol.make_client_capabilities(),
        require("cmp_nvim_lsp").default_capabilities(),
        {
            workspace = { configuration = true },
            textDocument = {
                completion = { completionItem = { snippetSupport = true } },
            },
        }
    )

    local extendedClientCapabilities =
        require("jdtls").extendedClientCapabilities
    extendedClientCapabilities.resolveAdditionalTextEditsSupport = true
    extendedClientCapabilities.classFileContentsSupport = true

    -------------------------------------------------------------------------
    -- 6. settings (java.*)
    --    Formatting OFF — conform.nvim owns formatting.
    --    generatesMetadataFilesAtProjectRoot = false → keeps
    --    .project/.classpath/.settings inside the workspace dir rather
    --    than littering the project tree.
    -------------------------------------------------------------------------
    local settings = {
        java = {
            import = {
                -- NB: generatesMetadataFilesAtProjectRoot is NOT honored
                -- here — JLSFsUtils reads it as a JVM system property only
                -- (see -D flag in cmd above). Leaving it out of settings
                -- so nobody is tempted to flip it here.
                gradle = { enabled = true },
                maven  = { enabled = true },
                exclusions = {
                    "**/node_modules/**",
                    "**/.metadata/**",
                    "**/archetype-resources/**",
                    "**/META-INF/maven/**",
                },
            },
            eclipse = { downloadSources = true },
            maven   = { downloadSources = true },
            implementationsCodeLens = { enabled = true },
            referencesCodeLens      = { enabled = true },

            references = { includeDecompiledSources = true },
            signatureHelp = { enabled = true, description = { enabled = true } },

            -- Fernflower-based built-in decompiler for class files without
            -- sources. Pair with classFileContentsSupport above.
            contentProvider = { preferred = "fernflower" },

            completion = {
                favoriteStaticMembers = {
                    "org.hamcrest.MatcherAssert.assertThat",
                    "org.hamcrest.Matchers.*",
                    "org.hamcrest.CoreMatchers.*",
                    "org.junit.jupiter.api.Assertions.*",
                    "java.util.Objects.requireNonNull",
                    "java.util.Objects.requireNonNullElse",
                    "org.mockito.Mockito.*",
                },
                importOrder = { "java", "javax", "com", "org" },
            },
            sources = {
                organizeImports = {
                    starThreshold       = 9999,
                    staticStarThreshold = 9999,
                },
            },
            codeGeneration = {
                toString = {
                    template =
                    "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
                },
                useBlocks = true,
                generateComments = true,
            },

            -- conform.nvim handles formatting → silence jdt.ls's.
            format = { enabled = false },

            configuration = {
                updateBuildConfiguration = "interactive",
                -- Adjust to your installed JDKs; jdt.ls itself needs JDK 21+,
                -- but projects may target older runtimes.
                runtimes = {
                    -- { name = "JavaSE-17", path = "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home" },
                    -- { name = "JavaSE-21", path = "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home", default = true },
                },
            },

            -- Verbose protocol trace; pair with -Dlog.level=ALL above.
            trace = { server = DEBUG and "verbose" or "off" },
        },
    }

    -------------------------------------------------------------------------
    -- 7. on_attach
    --    No buffer-local mappings for the global LSP defaults (gra, gri,
    --    grn, grr, grt, grx, gO, <C-s>) — those keep working the same way
    --    they do for every other LSP. Only Java-specific actions get
    --    <leader>j* below.
    -------------------------------------------------------------------------
    local function on_attach(client, bufnr)
        local jdtls = require("jdtls")

        pcall(jdtls.setup_dap, { hotcodereplace = "auto" })
        pcall(function()
            require("jdtls.dap").setup_dap_main_class_configs()
        end)

        local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs,
                { buffer = bufnr, desc = "Java: " .. desc })
        end

        map("n", "<leader>jo", jdtls.organize_imports, "Organize Imports")
        map("n", "<leader>jv", jdtls.extract_variable,  "Extract Variable")
        map("v", "<leader>jv",
            function() jdtls.extract_variable(true) end, "Extract Variable")
        map("n", "<leader>jc", jdtls.extract_constant,  "Extract Constant")
        map("v", "<leader>jc",
            function() jdtls.extract_constant(true) end, "Extract Constant")
        map("v", "<leader>jm",
            function() jdtls.extract_method(true) end,   "Extract Method")

        map("n", "<leader>jtc", function() require("jdtls.dap").test_class() end,
            "Test Class")
        map("n", "<leader>jtm", function() require("jdtls.dap").test_nearest_method() end,
            "Test Nearest Method")
        map("n", "<leader>jtp", function() require("jdtls.dap").pick_test() end,
            "Pick Test")

        if DEBUG then
            vim.notify(
                "[jdtls] attached to buffer " .. bufnr
                .. " (client id " .. client.id .. ")\n"
                .. "[jdtls] eclipse log: "
                .. workspace_dir .. "/.metadata/.log",
                vim.log.levels.INFO)
        end
    end

    -------------------------------------------------------------------------
    -- 8. start_or_attach via FileType autocmd
    -------------------------------------------------------------------------
    local jdtls_config_tbl = {
        cmd = cmd,
        root_dir = root_dir,
        capabilities = capabilities,
        settings = settings,
        init_options = {
            bundles = bundles,
            extendedClientCapabilities = extendedClientCapabilities,
            workspaceFolders = { "file://" .. root_dir },
        },
        on_attach = on_attach,
        handlers = {},
        flags = {
            allow_incremental_sync = true,
            server_side_fuzzy_completion = true,
        },
    }

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function()
            require("jdtls").start_or_attach(jdtls_config_tbl)
        end,
    })

    vim.api.nvim_create_user_command("JdtShowLogs", function()
        vim.cmd("tabnew " .. vim.lsp.get_log_path())
        vim.cmd("vsplit " .. workspace_dir .. "/.metadata/.log")
    end, { desc = "Open jdt.ls and Neovim LSP logs side-by-side" })

    vim.api.nvim_create_user_command("JdtWipeWorkspace", function()
        vim.fn.delete(workspace_dir, "rf")
        vim.notify("[jdtls] wiped " .. workspace_dir
            .. " — restart Neovim to re-import.", vim.log.levels.WARN)
    end, { desc = "Delete this project's jdt.ls workspace (forces re-import)" })
end

return M
