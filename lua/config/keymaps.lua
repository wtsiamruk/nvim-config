-- Set our "leader" key to 'space'
-- anywhere you see <leader> in any keymapping of any plugin it would be space
-- leader is used for key mappings in "normal" mode
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- removes search highlights after search is done
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Removes Search Highlights" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exists Terminal Mode" })

-- vim 'window' navigation
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move Focus to the left window" }) 
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move Focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move Focus to the lower window"})
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move Focus to the upper window"})
-- split setup
vim.keymap.set("n", "<leader>wv", ":vsplit<cr>", { desc = "[W]indow Split [V]ertical" })
vim.keymap.set("n", "<leader>wh", ":split<cr>", { desc = "[W]indow Split [H]orizontal" })

vim.keymap.set("v", "<", "<gv", { desc = "Indent left in visual mode" })
vim.keymap.set("v", ">" , ">gv", { desc = "Indent right in visual mode" })
