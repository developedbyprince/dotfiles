-- Godot 4.x GDScript support: LSP, treesitter, formatting, linting, debugging.
-- NOTE: the GDScript language server runs *inside* the Godot editor.
-- The Godot editor must be running (with this project open) for LSP to attach.
return {
  -- LSP: connect to the Godot editor's built-in language server (TCP 6005).
  -- nvim-lspconfig's lsp/gdscript.lua already defines cmd via
  -- vim.lsp.rpc.connect("127.0.0.1", 6005), so no cmd override is needed.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gdscript = {
          mason = false, -- not available in mason; served by the Godot editor
        },
      },
    },
  },

  -- Treesitter: syntax highlighting for .gd, .tscn/.tres, .gdshader
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "gdscript", "godot_resource", "gdshader" } },
    init = function()
      -- Neovim detects .tscn/.tres as filetype "gdresource", but the parser
      -- is named "godot_resource". Register the mapping so highlighting works.
      vim.treesitter.language.register("godot_resource", "gdresource")
    end,
  },

  -- Install gdtoolkit (provides gdformat + gdlint) via mason (pypi package)
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "gdtoolkit" } },
  },

  -- Formatting: gdformat (conform.nvim builtin)
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        gdscript = { "gdformat" },
      },
    },
  },

  -- Linting: gdlint (nvim-lint builtin)
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        gdscript = { "gdlint" },
      },
    },
  },

  -- Debugging: Godot's debug adapter (TCP 6006, enabled by default in Godot 4)
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      if not dap.adapters.godot then
        dap.adapters.godot = {
          type = "server",
          host = "127.0.0.1",
          port = 6006,
        }
      end
      dap.configurations.gdscript = {
        {
          type = "godot",
          request = "launch",
          name = "Launch Main Scene",
          project = "${workspaceFolder}",
        },
        {
          type = "godot",
          request = "launch",
          name = "Launch Current Scene",
          project = "${workspaceFolder}",
          scene = "current", -- requires Godot 4.2+
        },
      }
    end,
  },
}
