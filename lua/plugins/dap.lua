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
      vim.keymap.set("n", "<leader>ds", dap.continue,          { desc = "[D]ebug Continue / [S]tart" })
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "[D]ebug [B]reakpoint toggle" })
      vim.keymap.set("n", "<leader>do", dap.step_over,         { desc = "[D]ebug step [O]ver" })
      vim.keymap.set("n", "<leader>di", dap.step_into,         { desc = "[D]ebug step [I]nto" })
      vim.keymap.set("n", "<leader>dx", dap.step_out,          { desc = "[D]ebug step out [X]" })
      vim.keymap.set("n", "<leader>dq", dap.terminate,         { desc = "[D]ebug [Q]uit session" })
      vim.keymap.set("n", "<leader>du", dapui.toggle,          { desc = "[D]ebug [U]I toggle" })
      vim.keymap.set("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "[D]ebug conditional [B]reakpoint" })
    end,
  },
}
