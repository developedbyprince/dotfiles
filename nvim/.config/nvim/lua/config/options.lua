-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Share yanks/pastes with the system clipboard (Cmd+C / Cmd+V)
vim.opt.clipboard = "unnamedplus"
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
  -- Over SSH, use OSC 52 so yanks reach the local machine's clipboard
  vim.g.clipboard = "osc52"
end
