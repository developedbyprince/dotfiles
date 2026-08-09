-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Force the herdr-navigation plugin script to overwrite LazyVim's window rules
-- dofile(vim.fn.expand("~/src/personal/vim-herdr-navigation/editor/nvim.lua"))      dofile(vim.fn.expand("/Users/prince/.config/herdr/plugins/config/vim-herdr-navigation/editor/nvim.lua"))
dofile(vim.fn.expand("/Users/prince/.config/herdr/plugins/config/vim-herdr-navigation/editor/nvim.lua"))
