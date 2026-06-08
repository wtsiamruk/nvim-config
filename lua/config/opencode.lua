vim.g.opencode_opts = {
  server = {
    start  = function() vim.notify("opencode is not running — start it in an external terminal", vim.log.levels.WARN, { title = "opencode" }) end,
    stop   = function() end,
    toggle = function() end,
  },
}

vim.o.autoread = true -- Required for `opts.events.reload`

-- autoread only reloads when checktime is called; trigger it on focus/enter/idle
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  callback = function()
    if vim.fn.mode() ~= "c" then pcall(vim.cmd, "checktime") end
  end,
})

-- telescope picker: list sessions via GET /session, switch directly by ID
local function session_picker()
  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local function fmt_time(ts)
    if ts > 1e12 then ts = math.floor(ts / 1000) end
    local diff = os.time() - ts
    if     diff < 3600   then return math.floor(diff / 60)    .. "m ago"
    elseif diff < 86400  then return math.floor(diff / 3600)  .. "h ago"
    elseif diff < 604800 then return math.floor(diff / 86400) .. "d ago"
    else                      return os.date("%b %d", ts)
    end
  end

  local function build_picker(server, sessions)
    sessions = vim.tbl_filter(function(s)
      return not s.title:find("(@", 1, true)
    end, sessions)

    table.sort(sessions, function(a, b)
      local ta = (a.time and (a.time.updated or a.time.created)) or math.huge
      local tb = (b.time and (b.time.updated or b.time.created)) or math.huge
      if ta > 1e12 then ta = ta / 1000 end
      if tb > 1e12 then tb = tb / 1000 end
      return ta > tb
    end)

    local entries = { { id = nil, title = "+ New session" } }
    vim.list_extend(entries, sessions)

    local function switch(sel)
      local srv = sel.value._server or server
      if not sel.value.id then
        require("opencode").command("session.new")
        return
      end
      if srv then srv:select_session(sel.value.id) end
    end

    pickers.new({}, {
      prompt_title     = "opencode sessions",
      sorting_strategy = "ascending",
      layout_config    = { prompt_position = "top" },
      finder = finders.new_table({
        results = entries,
        entry_maker = function(e)
          if not e.id then
            return { value = e, display = e.title, ordinal = "new session" }
          end
          local ts   = e.time and (e.time.updated or e.time.created) or 0
          local date = ts > 0 and fmt_time(ts) or "unknown"
          local pad  = math.max(1, 48 - #e.title)
          return { value = e, display = e.title .. string.rep(" ", pad) .. date, ordinal = e.title }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          switch(action_state.get_selected_entry())
        end)
        -- <C-x>: compact the selected session then switch to it
        map({ "i", "n" }, "<C-x>", function()
          actions.close(prompt_bufnr)
          local sel = action_state.get_selected_entry()
          switch(sel)
          if sel.value.id and server then
            vim.defer_fn(function()
              require("opencode").command("session.compact")
            end, 200)
          end
        end)
        return true
      end,
    }):find()
  end

  local Server = require("opencode.server")
  Server.get_all():next(function(servers)
    local all, pending = {}, #servers
    for _, srv in ipairs(servers) do
      srv:get_sessions(function(sessions)
        for _, s in ipairs(sessions) do s._server = srv end
        vim.list_extend(all, sessions)
        pending = pending - 1
        if pending == 0 then
          vim.schedule(function() build_picker(servers[1], all) end)
        end
      end)
    end
  end):catch(function()
    Server.get():next(function(server)
      server:get_sessions(function(sessions)
        vim.schedule(function() build_picker(server, sessions) end)
      end)
    end, function(_) build_picker(nil, {}) end)
  end)
end

vim.keymap.set({ "n", "x" }, "<leader>oa", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask opencode…" })
vim.keymap.set({ "n", "x" }, "<leader>oe", function() require("opencode").select() end,                          { desc = "Execute opencode action…" })
vim.keymap.set({ "n", "x" }, "<leader>or", function() return require("opencode").operator("@this ") end,         { desc = "Add range to opencode", expr = true })
vim.keymap.set("n",          "<leader>ol", function() return require("opencode").operator("@this ") .. "_" end,  { desc = "Add line to opencode", expr = true })
vim.keymap.set("n",          "<leader>os", session_picker,                                                       { desc = "opencode: pick session" })
