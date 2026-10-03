-- Enable LSP code lenses globally (LazyVim defaults this to false).
-- <leader>cc runs the lens under the cursor, <leader>cC refreshes lenses.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      codelens = { enabled = true },
    },
  },
}
