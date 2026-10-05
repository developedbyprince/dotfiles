-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Elixir's ftplugin re-indents as soon as `|` or `>` is typed. Treesitter can't
-- parse a half-typed `|>`, so the pipe gets pushed one level too deep.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "elixir", "heex" },
  callback = function()
    vim.opt_local.indentkeys:remove({ "0|>", ">" })
  end,
})
