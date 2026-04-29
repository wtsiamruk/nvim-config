return {
  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",  -- required by nvim-dap-ui
    },
    config = function()
      local dap    = require("dap")
      local dapui  = require("dapui")

      dapui.setup()

      -- Auto-open/close UI with the DAP session
      dap.listeners.after.event_initialized["dapui_config"]  = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"]  = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"]      = function() dapui.close() end

      -- Keymaps
      vim.keymap.set("n", "<leader>jdc", dap.continue,          { desc = "[J]ava [D]ebug [C]ontinue / start" })
      vim.keymap.set("n", "<leader>jdb", dap.toggle_breakpoint, { desc = "[J]ava [D]ebug [B]reakpoint toggle" })
      vim.keymap.set("n", "<leader>jdo", dap.step_over,         { desc = "[J]ava [D]ebug step [O]ver" })
      vim.keymap.set("n", "<leader>jdi", dap.step_into,         { desc = "[J]ava [D]ebug step [I]nto" })
      vim.keymap.set("n", "<leader>jdx", dap.step_out,          { desc = "[J]ava [D]ebug step out [X]" })
      vim.keymap.set("n", "<leader>jdq", dap.terminate,         { desc = "[J]ava [D]ebug [Q]uit session" })
      vim.keymap.set("n", "<leader>jdu", dapui.toggle,          { desc = "[J]ava [D]ebug [U]I toggle" })
      vim.keymap.set("n", "<leader>jdB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "[J]ava [D]ebug conditional [B]reakpoint" })
    end,
  },
}
