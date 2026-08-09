return {
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
    config = function()
      dofile(vim.fn.expand("/Users/prince/.config/herdr/plugins/config/vim-herdr-navigation/editor/nvim.lua"))
    end,
  },
}
