-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

-- Prevent my muscle memory of Undo from backgrounding the editor :|
-- vim.keymap.set({'n', 'i', 'v'}, '<C-z>', '<nop>', { silent = true })
vim.keymap.set({ "n", "i", "v" }, "<C-z>", "u", { silent = true })
