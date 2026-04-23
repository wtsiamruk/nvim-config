-- =============================================================================
-- lua/config/jdtls.lua
--
-- Self-contained jdtls configuration module.
-- Exposes:
--   M.make_syntax_config(root_dir, workspace_dir)  → config table (syntax server)
--   M.make_standard_config(root_dir, workspace_dir, on_attach) → config table (full server)
--
-- Does NOT require("jdtls") and does NOT call start_or_attach.
-- That is the responsibility of after/ftplugin/java.lua.
-- =============================================================================
local M = {}

-- =============================================================================
-- 1. PATH RESOLUTION
--    All paths are computed once at module load time.
--    We assert early so misconfigurations surface immediately with clear messages
--    rather than cryptic LSP startup failures.
-- =============================================================================

local mason_pkg   = vim.fn.expand("$HOME/.local/share/nvim/mason/packages")
local jdtls_base  = mason_pkg .. "/jdtls"
local lombok_jar  = jdtls_base .. "/lombok.jar"

-- The Equinox launcher jar name includes a version number, so we glob for it.
-- vim.fn.glob returns "" when nothing matches — caught by the assert below.
local launcher_jar = vim.fn.glob(jdtls_base .. "/plugins/org.eclipse.equinox.launcher_*.jar")

assert(
  launcher_jar ~= "",
  "[jdtls.lua] Equinox launcher jar not found under " .. jdtls_base .. "/plugins/. "
    .. "Run :MasonInstall jdtls to fix this."
)

assert(
  vim.fn.filereadable(lombok_jar) == 1,
  "[jdtls.lua] lombok.jar not found at " .. lombok_jar .. ". "
    .. "Re-install jdtls via Mason: :MasonInstall jdtls"
)

-- Java binary: we use the sdkman "current" symlink so the user's active SDK is
-- always used, regardless of which JDK versions are installed.
local java_bin = vim.fn.expand("$HOME/.sdkman/candidates/java/current/bin/java")

assert(
  vim.fn.executable(java_bin) == 1,
  "[jdtls.lua] java binary not found at " .. java_bin .. ". "
    .. "Ensure sdkman is installed and a Java candidate is set as current."
)

-- =============================================================================
-- 2. PLATFORM + ARCHITECTURE DETECTION
--    Selects the correct jdtls OSGi config dir for the current machine.
--
--    jdtls ships these config variants:
--      config_mac          macOS  x86_64  (Intel)
--      config_mac_arm      macOS  arm64   (Apple Silicon)
--      config_linux        Linux  x86_64
--      config_linux_arm    Linux  arm64   (e.g. Raspberry Pi, ARM servers)
--      config_win          Windows (not handled here)
--
--    config_ss_* mirrors exist for every platform (syntax server variants).
--
--    vim.uv.os_uname():
--      .sysname → "Darwin" | "Linux" | "Windows_NT"
--      .machine → "arm64" | "x86_64" | "aarch64"
--                 (Linux uses "aarch64" for 64-bit ARM; macOS uses "arm64")
-- =============================================================================

local uname   = vim.uv.os_uname()
local sysname = uname.sysname                         -- "Darwin" or "Linux"
local machine = uname.machine                         -- "arm64" / "aarch64" / "x86_64"
local is_arm  = (machine == "arm64" or machine == "aarch64")

local platform_suffix
if sysname == "Darwin" then
  platform_suffix = is_arm and "_mac_arm" or "_mac"
elseif sysname == "Linux" then
  platform_suffix = is_arm and "_linux_arm" or "_linux"
else
  -- Windows_NT — unlikely in this setup but explicit beats silent breakage
  error("[jdtls.lua] Windows is not supported by this config. Platform: " .. sysname)
end

-- Standard server OSGi platform config (full Eclipse runtime)
local config_dir = jdtls_base .. "/config" .. platform_suffix

-- Syntax server OSGi platform config (stripped-down Eclipse runtime)
-- The config_ss_* dirs ship with the jdtls Mason package alongside config_*.
local config_ss_dir = jdtls_base .. "/config_ss" .. platform_suffix

-- =============================================================================
-- 3. SDKMAN RUNTIME DETECTION
--    Enumerates ~/.sdkman/candidates/java/* to build a configuration.runtimes
--    list. Each directory name is parsed for its major version number and mapped
--    to the jdtls ExecutionEnvironment naming convention:
--      Java  8 and below → "JavaSE-1.X"
--      Java  9 and above → "JavaSE-X"
--
--    The "current" symlink is resolved to its real target so we can flag the
--    active candidate as default = true.
-- =============================================================================

local function detect_runtimes()
   -- Fail fast: sdkman itself must be present.
  assert(
    vim.fn.isdirectory(vim.fn.expand("$HOME/.sdkman")) == 1,
    "[jdtls.lua] sdkman not found at ~/.sdkman. "
      .. "Install sdkman (https://sdkman.io) or adapt detect_runtimes() "
      .. "to your JDK manager (e.g. Homebrew, asdf)."
  )

  -- Fail fast: the java candidates directory must exist inside sdkman.
  assert(
    vim.fn.isdirectory(sdkman_java) == 1,
    "[jdtls.lua] No Java candidates found at ~/.sdkman/candidates/java. "
      .. "Install at least one JDK via sdkman: sdk install java"
  )

  -- Fail fast: "current" must be set — otherwise java_bin (used in build_cmd)
  -- points at a non-existent binary and jdtls will silently fail to start.
  assert(
    vim.fn.isdirectory(sdkman_java .. "/current") == 1,
    "[jdtls.lua] No default JDK set in sdkman (~/.sdkman/candidates/java/current missing). "
      .. "Set one with: sdk default java <version>"
  )

  local runtimes    = {}
  local sdkman_java = vim.fn.expand("$HOME/.sdkman/candidates/java")

  -- Resolve the "current" symlink once; we compare against it per-candidate.
  local current_real = vim.fn.resolve(sdkman_java .. "/current")

  -- glob returns a flat list of paths matching the pattern.
  local candidates = vim.fn.glob(sdkman_java .. "/*", false, true)

  for _, path in ipairs(candidates) do
    local name = vim.fn.fnamemodify(path, ":t")

    -- Skip the "current" symlink itself — it's not a real candidate entry.
    if name ~= "current" and vim.fn.isdirectory(path) == 1 then
      -- sdkman version strings: "21.0.8-jbr", "17.0.11-tem", "11.0.23-ms", etc.
      -- We only need the leading major version number.
      local major_str = name:match("^(%d+)")

      if major_str then
        local major = tonumber(major_str)

        -- Map major version → ExecutionEnvironment name expected by jdtls.
        local ee_name = (major <= 8)
          and ("JavaSE-1." .. major_str)
          or  ("JavaSE-" .. major_str)

        table.insert(runtimes, {
          name    = ee_name,
          path    = path,
          -- Mark as default if this candidate is what "current" points to.
          default = (vim.fn.resolve(path) == current_real),
        })
end

return M

-- =============================================================================
-- USAGE
--
-- This module only builds config tables. The caller is responsible for
-- starting the server. Typical setup in after/ftplugin/java.lua:
--
--   local jdtls     = require("jdtls")
--   local cfg       = require("config.jdtls")
--   local root_dir  = jdtls.setup.find_root({ "pom.xml", "build.gradle", ".git" })
--   local workspace = vim.fn.expand("~/.local/share/nvim/jdtls-workspace/")
--                     .. vim.fn.fnamemodify(root_dir, ":t")
--
--   jdtls.start_or_attach(cfg.make_standard_config(root_dir, workspace, on_attach))
--
-- For buffers that only need syntax / diagnostics (e.g. read-only library
-- sources), use make_syntax_config instead — it skips DAP and test bundles:
--
--   jdtls.start_or_attach(cfg.make_syntax_config(root_dir, workspace))
--
-- Eclipse formatter XML
--   Export from IDEA via Settings → Editor → Code Style → Java → ⚙ → Export →
--   "Eclipse Code Formatter Profile", then uncomment in make_settings():
--     settings = { url = vim.fn.expand("~/.config/nvim/java-formatter.xml") }
-- =============================================================================

    end
  end

  return runtimes
end

-- =============================================================================
-- 4. BUNDLE RESOLUTION
--    Globs Mason package directories for the three extension jar sets:
--      • java-debug-adapter  — enables DAP (nvim-dap) for Java
--      • java-test           — enables test running via jdtls
--      • vscode-java-decompiler — enables navigating into .class files in jars
--
--    IMPORTANT: bundles must only be passed to the STANDARD server.
--    The syntax server will crash if it receives these jars.
-- =============================================================================

local function resolve_bundles()
  -- Debug adapter: single jar matching com.microsoft.java.debug.plugin-*.jar
  local debug_jars = vim.split(
    vim.fn.glob(
      mason_pkg .. "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
    ),
    "\n",
    { trimempty = true }
  )

  -- Test runner: multiple jars in the server/ directory
  local test_jars = vim.split(
    vim.fn.glob(mason_pkg .. "/java-test/extension/server/*.jar"),
    "\n",
    { trimempty = true }
  )

  -- Decompiler: jar(s) for navigating into compiled .class files
  local decompiler_jars = vim.split(
    vim.fn.glob(mason_pkg .. "/vscode-java-decompiler/server/*.jar"),
    "\n",
    { trimempty = true }
  )

  local all = {}
  vim.list_extend(all, debug_jars)
  vim.list_extend(all, test_jars)
  vim.list_extend(all, decompiler_jars)
  return all
end

-- Resolved once at module load; reused for every standard config call.
local bundles = resolve_bundles()

-- =============================================================================
-- 5. CMD BUILDER
--    Constructs the full java invocation for either the syntax or standard
--    server.
--
--    Key decisions:
--      • -Xms256m / -Xmx2G: low initial heap keeps startup snappy; generous max
--        handles large enterprise projects with many transitive dependencies.
--      • -Dlog.level=ERROR: suppress the verbose jdtls INFO/DEBUG log spam that
--        floods :LspLog. Change to ALL when debugging jdtls startup issues.
--      • -javaagent:<lombok.jar>: must appear BEFORE -jar so the agent can
--        instrument the Java compiler before Eclipse OSGi loads.
--      • -Dsyntaxserver=true: inserted at position 2 (immediately after the java
--        binary path) so it is a system property visible to the OSGi bootstrap.
--        Placing it after -jar would make it an Eclipse application argument,
--        not a JVM system property, and the syntax mode would not activate.
--      • --add-modules=ALL-SYSTEM, --add-opens: required for Java 9+ module
--        system. Eclipse/OSGi uses deep reflection into java.base internals;
--        without these the server crashes with InaccessibleObjectException.
-- =============================================================================

local function build_cmd(workspace_dir, is_syntax)
  local args = {
    java_bin,

    -- ── Required Eclipse/OSGi system properties ──────────────────────────
    -- These three are non-negotiable; the server refuses to start without them.
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",

    -- ── Logging ──────────────────────────────────────────────────────────
    -- log.protocol=true streams LSP wire messages to the jdtls log file.
    -- Useful for debugging protocol issues; harmless in production.
    "-Dlog.protocol=true",
    "-Dlog.level=ERROR",

    -- ── JVM heap ─────────────────────────────────────────────────────────
    "-Xms256m",  -- initial: small so the JVM starts without pre-allocating RAM
    "-Xmx2G",   -- max: 2 GB handles most projects; raise to 4G for monorepos

    -- ── Java 9+ module system ─────────────────────────────────────────────
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",

    -- ── Lombok ───────────────────────────────────────────────────────────
    -- javaagent instruments the ECJ (Eclipse Compiler for Java) at load time.
    -- This must come before -jar; agents listed after -jar are ignored.
    "-javaagent:" .. lombok_jar,

    -- ── Equinox OSGi launcher ─────────────────────────────────────────────
    -- Everything after -jar is an Eclipse application argument, not a JVM arg.
    "-jar", launcher_jar,

    -- ── Platform configuration dir ────────────────────────────────────────
    -- config_ss_* is a stripped-down OSGi config for the syntax server.
    -- config_*    is the full OSGi config for the standard server.
    "-configuration", is_syntax and config_ss_dir or config_dir,

    -- ── Per-project workspace data dir ───────────────────────────────────
    -- Stores the project index, workspace state, and build artifacts.
    -- Must be an absolute path and unique per project root.
    "-data", workspace_dir,
  }

  -- Insert -Dsyntaxserver=true at position 2 (right after java_bin) so it is
  -- processed as a JVM system property before any Eclipse code runs.
  if is_syntax then
    table.insert(args, 2, "-Dsyntaxserver=true")
  end

  return args
end

-- =============================================================================
-- 6. SETTINGS BLOCK
--    The full settings.java table sent to jdtls as workspace configuration.
--    These mirror the settings that make IntelliJ IDEA and VSCode's Java
--    extension feel polished and productive.
--
--    Called once per make_standard_config() call; each config gets its own
--    fresh table to avoid shared-state mutations across buffers.
-- =============================================================================

local function make_settings()
  return {
    java = {

      -- ── Build ─────────────────────────────────────────────────────────────
      -- autobuild: continuously compile on save, keeping diagnostics current.
      autobuild = { enabled = true },
      -- Run up to 4 project builds in parallel (useful in multi-module projects).
      maxConcurrentBuilds = 4,

      -- ── Completion ───────────────────────────────────────────────────────
      completion = {
        enabled = true,

        -- Import order shown in the "add import" quick fix and organise imports.
        -- Mirrors the IDEA default: stdlib → extensions → common frameworks.
        importOrder = { "java", "javax", "jakarta", "org", "com" },

        -- Strip JDK internal packages from completion results — they appear in
        -- type lookups but are almost never what you want in application code.
        filteredTypes = {
          "com.sun.*",
          "sun.*",
          "jdk.*",
          "org.graalvm.*",
          "io.micrometer.shaded.*",
        },

        -- Propose these static members without needing to type the class name.
        -- Mirrors IDEA's "Add on-demand static import" feature for test libraries.
        favoriteStaticMembers = {
          "org.junit.Assert.*",
          "org.junit.Assume.*",
          "org.junit.jupiter.api.Assertions.*",
          "org.junit.jupiter.api.Assumptions.*",
          "org.junit.jupiter.api.DynamicContainer.*",
          "org.junit.jupiter.api.DynamicTest.*",
          "org.mockito.Mockito.*",
          "org.mockito.ArgumentMatchers.*",
          "org.hamcrest.MatcherAssert.assertThat",
          "org.hamcrest.Matchers.*",
        },

        -- On method completion, fill in named placeholder snippets for each
        -- parameter. Mirrors IDEA's "Insert parameter name hints" on completion.
        guessMethodArguments = "insertParameterNames",

        -- Replace the token under the cursor rather than inserting before it.
        overwrite = true,

        -- Postfix templates: .var, .for, .fori, .sout, .nn, .instanceof, etc.
        postfix = { enabled = true },

        -- Chain completion: after typing ".", propose the next fluent method.
        chain = { enabled = true },

        maxResults = 50,

        -- Case-insensitive first letter: "str" matches "String" and "StringBuilder".
        matchCase = "firstletter",

        -- Show each overload as a separate item (not collapsed under one entry).
        collapseCompletionItems = false,

        -- Defer resolving the full text edit for a completion item until it is
        -- actually selected — measurably reduces completion popup latency.
        lazyResolveTextEdit = { enabled = true },
      },

      -- ── Imports ──────────────────────────────────────────────────────────
      sources = {
        organizeImports = {
          -- 99 = never collapse to star imports unless you have 99+ of one package.
          -- Keeps imports explicit and diff-friendly.
          starThreshold       = 99,
          staticStarThreshold = 99,
        },
      },
      saveActions = {
        -- Organise imports is triggered explicitly via <D-A-o> keymap.
        -- Auto-organising on save causes unexpected file changes mid-edit
        -- and interferes with work-in-progress code that has unresolved types.
        organizeImports = false,
      },

      -- ── Formatting ───────────────────────────────────────────────────────
      format = {
        enabled      = true,
        insertSpaces = true,
        tabSize      = 4,
        -- Format on type disabled: IDEA's mental model is explicit Cmd+L.
        onType   = { enabled = false },
        comments = { enabled = true },
        -- To use a custom Eclipse formatter XML (e.g. Google Style or your team's
        -- profile), uncomment the line below and point it at the XML file:
        -- settings = { url = vim.fn.expand("~/.config/nvim/java-formatter.xml") },
      },

      -- ── Inlay hints ──────────────────────────────────────────────────────
      -- "literals": show parameter name hints only when the argument is a
      -- literal value (string, number, boolean). This is the least-noisy mode
      -- and matches what recent IDEA versions enable by default.
      inlayhints = {
        parameterNames = {
          enabled    = "literals",
          exclusions = {},
        },
      },

      -- ── Signature help ────────────────────────────────────────────────────
      -- Shows method signature + Javadoc when typing arguments.
      -- Triggered explicitly via Cmd+P keymap (Insert mode).
      signatureHelp = {
        enabled     = true,
        description = { enabled = true },
      },

      -- ── Code lens ─────────────────────────────────────────────────────────
      -- "N usages" inline above fields and methods — like IDEA's usage count.
      referencesCodeLens = { enabled = true },
      -- "N implementations" above interfaces and abstract classes.
      implementationCodeLens = "types",

      -- ── Code generation ───────────────────────────────────────────────────
      codeGeneration = {
        toString = {
          -- Produces: ClassName{field1=value1, field2=value2}
          template          = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
          codeStyle         = "STRING_BUILDER_CHAINED",
          skipNullValues    = false,
          listArrayContents = true,
        },
        hashCodeEquals = {
          -- Use instanceof for type check (Java 16+ pattern matching compatible).
          useInstanceof   = true,
          -- Use java.util.Objects.hash() and Objects.equals() (Java 7+).
          useJava7Objects = true,
        },
        -- Wrap single-statement if/for/while bodies in braces.
        useBlocks         = true,
        generateComments  = false,
        -- Insert generated code at the cursor position, not at the end of class.
        insertionLocation = "beforeCursor",
      },

      -- ── Diagnostics & null analysis ───────────────────────────────────────
      errors = {
        -- Warn (not error) on incomplete classpath so the editor stays usable
        -- during partial Maven/Gradle imports.
        incompleteClasspath = { severity = "warning" },
      },
      diagnostic = {
        -- Null-safety static analysis — one of IDEA's strongest diagnostic edges.
        -- "automatic" enables it without requiring explicit annotation configuration.
        nullAnalysis = {
          mode = "automatic",
          nonnull = {
            "javax.annotation.Nonnull",
            "org.eclipse.jdt.annotation.NonNull",
            "org.springframework.lang.NonNull",
            "lombok.NonNull",
          },
          nullable = {
            "javax.annotation.Nullable",
            "org.eclipse.jdt.annotation.Nullable",
            "org.springframework.lang.Nullable",
          },
        },
      },

      -- ── Build configuration ───────────────────────────────────────────────
      configuration = {
        -- Automatically refresh classpath when pom.xml or build.gradle changes.
        -- "interactive" would prompt each time; "automatic" keeps the IDE in sync.
        updateBuildConfiguration = "automatic",
        maven    = { downloadSources = true },
        -- Populated dynamically from ~/.sdkman/candidates/java/* at module load.
        runtimes = detect_runtimes(),
      },

      -- ── Project import ────────────────────────────────────────────────────
      import = {
        gradle = {
          enabled  = true,
          -- Prefer the project's own gradlew over a system Gradle installation.
          wrapper  = { enabled = true },
          -- Run annotation processors (needed for Lombok, MapStruct, Dagger, etc.).
          annotationProcessing = { enabled = true },
          offline  = { enabled = false },
        },
        maven = {
          enabled = true,
          offline = { enabled = false },
          -- Download sources so you can navigate into library code.
          downloadSources = true,
        },
        -- Glob patterns for directories jdtls should not scan during import.
        -- Keeps the import fast on projects that have nested JS tooling or
        -- large generated-output directories.
        exclusions = {
          "**/node_modules/**",
          "**/.metadata/**",
          "**/archetype-resources/**",
          "**/META-INF/maven/**",
          "**/.gradle/**",
          "**/.git/**",
          "**/build/**",
          "**/target/**",
        },
      },

      -- ── References ────────────────────────────────────────────────────────
      references = {
        -- Navigate into decompiled source for 3rd-party .jar files — a core
        -- IDEA feature that makes exploring library internals effortless.
        includeDecompiledSources = true,
        -- Include getter/setter accessors in "Find Usages" results.
        includeAccessors = true,
      },

      -- ── Maven sources ─────────────────────────────────────────────────────
      maven = {
        downloadSources  = true,
        updateSnapshots  = false,
      },

      -- ── Miscellaneous ─────────────────────────────────────────────────────
      telemetry      = { enabled = false },
      -- Smart expand/shrink selection (mapped to Alt+Up/Down in IDEA).
      selectionRange = { enabled = true },
      foldingRange   = { enabled = true },
      rename         = { enabled = true },
      edit = {
        -- Re-validate all open Java buffers when any file in the project changes.
        validateAllOpenBuffersOnChanges = true,
        -- Automatically move the semicolon to the correct position when typed
        -- inside a method call or for-loop — an IDEA quality-of-life feature.
        smartSemicolonDetection = { enabled = true },
      },
      symbols = {
        -- Include method declarations from source files in workspace symbol search.
        includeSourceMethodDeclarations = true,
      },
    },
  }
end

-- =============================================================================
-- 7. EXTENDED CLIENT CAPABILITIES
--    Sent to jdtls inside initializationOptions.extendedClientCapabilities.
--    These unlock jdtls features beyond standard LSP that require the client
--    (Neovim) to handle interactive prompts and advanced command dispatching.
--
--    Without these, generate/refactor operations degrade to plain code actions
--    with no interactive selection dialogs.
-- =============================================================================

local extended_client_capabilities = {
  -- Stream $/progress notifications so we can detect "ServiceReady" and switch
  -- from the syntax server to the standard server at the right moment.
  progressReportProvider = true,

  -- Render decompiled .class file contents in the editor buffer.
  -- Required for navigating into library internals (depends on vscode-java-decompiler).
  classFileContentsSupport = true,

  -- Interactive generation prompts — these enable IDEA-style "Generate" dialogs
  -- for each operation instead of silent code insertion.
  generateToStringPromptSupport        = true,
  hashCodeEqualsPromptSupport          = true,
  generateConstructorsPromptSupport    = true,
  generateDelegateMethodsPromptSupport = true,
  overrideMethodsPromptSupport         = true,
  advancedGenerateAccessorsSupport     = true,

  -- Advanced refactoring: these tell jdtls to dispatch Extract operations as
  -- interactive commands (with selection prompts) rather than one-shot code
  -- actions. Required for the extract_variable/method/constant keymaps to
  -- show the selection dialog when multiple positions are possible.
  advancedExtractRefactoringSupport            = true,
  advancedOrganizeImportsSupport               = true,
  advancedIntroduceParameterRefactoringSupport = true,

  -- Enable moving a Java type, static member, or instance method to another
  -- class/package via code action.
  moveRefactoringSupport = true,

  -- When an extract refactoring is triggered without a precise visual selection,
  -- jdtls will infer candidates and prompt the user to choose one.
  -- Without this, the operation silently fails if the cursor is ambiguous.
  inferSelectionSupport = {
    "extractMethod",
    "extractVariable",
    "extractConstant",
    "extractField",
  },

  -- Exit immediately on LSP shutdown() without waiting for a separate exit().
  -- Prevents dangling jdtls JVM processes when Neovim quits.
  shouldLanguageServerExitOnShutdown = true,

  -- Allow jdtls to use LSP snippet syntax inside code action text edits.
  -- Enables placeholder-based insertion for generated code.
  snippetEditSupport = true,
}

-- =============================================================================
-- 8. PUBLIC API
-- =============================================================================

--- Returns a jdtls config table for the syntax server (lightweight, fast start).
---
--- The syntax server provides:
---   • Document symbols / outline
---   • Basic hover / Javadoc
---   • Syntax error diagnostics
---   • Formatting
---   • Basic completion (JDK types + open source files)
---
--- It does NOT provide:
---   • Cross-project type resolution
---   • Dependency-aware completion (3rd-party libs)
---   • Full diagnostics (only syntax, not semantic)
---   • DAP / test running
---   • Refactoring
---
--- @param root_dir string   Absolute path to the project root.
--- @param workspace_dir string  Absolute path to the per-project data dir.
--- @return table  Config table ready to pass to jdtls.start_or_attach().
function M.make_syntax_config(root_dir, workspace_dir)
  return {
    -- Name used by nvim-jdtls to identify this client instance.
    -- Must differ from the standard server name so both can coexist briefly.
    name     = "jdtls_syntax",
    cmd      = build_cmd(workspace_dir, true),
    root_dir = root_dir,

    init_options = {
      -- IMPORTANT: syntax server crashes if bundles are provided.
      -- Debug adapter and test runner jars are only valid for Standard mode.
      bundles = {},
    },

    settings = {
      java = {
        -- Explicitly declare the intended launch mode in settings.
        -- The actual mode is controlled by -Dsyntaxserver=true in the cmd;
        -- this setting is informational for the server.
        server     = { launchMode = "SyntaxServer" },
        completion = { enabled = true },
        signatureHelp = { enabled = true },
        format     = { enabled = true },
      },
    },

    -- Use full client capabilities so the syntax server can offer everything
    -- it supports (hover, completion, symbols, formatting).
    capabilities = vim.lsp.protocol.make_client_capabilities(),

    -- No on_attach for the syntax server.
    -- Keymaps, DAP setup, and code generation are registered only when the
    -- standard server attaches — they depend on features the syntax server lacks.
  }
end

--- Returns a jdtls config table for the standard (full compilation) server.
---
--- The standard server provides everything the syntax server does, plus:
---   • Full semantic diagnostics and null-safety analysis
---   • Complete dependency-aware completion
---   • All refactoring operations (extract, rename, move, introduce parameter)
---   • Code generation (toString, hashCode, constructor, getters/setters)
---   • DAP debugging via java-debug-adapter
---   • Test running via java-test
---   • Navigation into decompiled library sources
---
--- @param root_dir string   Absolute path to the project root.
--- @param workspace_dir string  Absolute path to the per-project data dir.
--- @param on_attach function|nil  Called when the client attaches to a buffer.
---                                 Receives (client, bufnr). Sets keymaps + DAP.
--- @return table  Config table ready to pass to jdtls.start_or_attach().
function M.make_standard_config(root_dir, workspace_dir, on_attach)
  return {
    name     = "jdtls",
    cmd      = build_cmd(workspace_dir, false),
    root_dir = root_dir,

    init_options = {
      -- All extension jars: debug adapter + test runner + decompiler.
      bundles = bundles,
      extendedClientCapabilities = extended_client_capabilities,
    },

    settings     = make_settings(),
    capabilities = vim.lsp.protocol.make_client_capabilities(),

    -- on_attach is provided by after/ftplugin/java.lua and sets all keymaps,
    -- configures nvim-dap, and runs setup_dap_main_class_configs().
    on_attach = on_attach,
  }
end

