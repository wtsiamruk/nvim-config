return {
  {
      'nvim-telescope/telescope.nvim', version = 'v0.2.2', tag = 'v0.2.2',
      dependencies = {
          'nvim-lua/plenary.nvim',
          -- optional but recommended
          { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      },
      config = function()
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>ff', function()
          builtin.find_files({ no_ignore = true, hidden = true })
        end, { desc = 'Telescope find files' })
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
        vim.keymap.set('n', '<leader>fd', builtin.diagnostics, { desc = 'Telescope find diagnostics' })
        vim.keymap.set('n', '<leader>fr', builtin.resume, { desc = 'Telescope find resume' })
        vim.keymap.set('n', '<leader>fe', builtin.oldfiles, { desc = 'Telescope find recent files' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers (aka tabs)' })
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
        vim.keymap.set('n', '<leader>fn', function() require("telescope").extensions.fidget.fidget() end, { desc = 'Fidget notification history' })
      end
  },
  {
    'nvim-telescope/telescope-ui-select.nvim',
    config = function()
      local actions = require("telescope.actions")

      require("telescope").setup({
        extensions = {
          ['ui-select'] = {
            require("telescope.themes").get_dropdown {}
          }
        },
        defaults = {
          vimgrep_arguments = {
            "rg", "--color=never", "--no-heading", "--with-filename",
            "--line-number", "--column", "--smart-case",
            "--no-ignore",
            "--hidden",
          },
        },
        mappings = {
          i = {
            -- use <cltr› + n to go to the next option
            ["<C-n>"] = actions. cycle_history_next,
            -- use <cltr> + p to go to the previous option
            ["<C-p>"] = actions.cycle_history_prev,
            -- use <cltr> + j to go to the next preview
            ["<C-j>"] = actions. move_selection_next,
            -- use <cltr> + k to go to the previous preview
            ["<C-k>"] = actions. move_selection_previous,
          }

        },
      })
      require("telescope").load_extension("ui-select")
    end
  }
}
