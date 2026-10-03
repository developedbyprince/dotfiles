-- Elixir debugging via ElixirLS's debug adapter (installed by the lang.elixir extra).
return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")

      -- Adapter: Mason's `elixir-ls-debugger` script (on PATH via Mason's bin dir).
      dap.adapters.mix_task = {
        type = "executable",
        command = vim.fn.exepath("elixir-ls-debugger"),
        args = {},
      }

      -- Read the app's root module (e.g. "MyApp") from mix.exs so only your
      -- modules are interpreted. Interpreting every dependency is very slow.
      local function app_module()
        local mix = vim.fs.find("mix.exs", { upward = true, path = vim.fn.expand("%:p:h") })[1]
        if mix then
          for _, line in ipairs(vim.fn.readfile(mix)) do
            local mod = line:match("defmodule%s+([%w_]+)%.MixProject")
            if mod then
              return mod
            end
          end
        end
      end

      -- Settings shared by every Elixir config.
      local base = {
        type = "mix_task", -- use the adapter above
        request = "launch", -- ElixirLS only supports launch
        projectDir = "${workspaceFolder}", -- directory with mix.exs
        debugAutoInterpretAllModules = false, -- don't interpret deps (huge speed-up)
        debugInterpretModulesPatterns = function()
          local mod = app_module()
          if not mod then
            return {} -- unknown app: interpret nothing extra
          end
          -- MyApp, MyApp.*, and Phoenix's MyAppWeb, MyAppWeb.*
          return { mod, mod .. ".*", mod .. "Web", mod .. "Web.*" }
        end,
      }

      local function cfg(extra)
        return vim.tbl_extend("force", base, extra)
      end

      dap.configurations.elixir = {
        cfg({
          name = "mix test (all)",
          task = "test", -- runs `mix test`
          taskArgs = { "--trace" }, -- run tests serially with per-test output (needed for stepping)
          startApps = true, -- start the app's OTP applications first
          requireFiles = { -- load test helpers and test files into the debugger
            "test/**/test_helper.exs",
            "test/**/*_test.exs",
          },
          env = { MIX_ENV = "test" },
        }),
        cfg({
          name = "mix test (current file)",
          task = "test",
          taskArgs = function() -- just this test file
            return { vim.fn.expand("%:p"), "--trace" }
          end,
          startApps = true,
          requireFiles = { "test/**/test_helper.exs", "${file}" },
          env = { MIX_ENV = "test" },
        }),
        cfg({
          name = "phx.server",
          task = "phx.server", -- runs `mix phx.server`
          env = { MIX_ENV = "dev" },
          exitAfterTaskReturns = false, -- keep the session alive while the server runs
        }),
        cfg({
          name = "mix task (prompt)",
          task = function() -- e.g. run, my.task
            return vim.fn.input("mix task: ", "run")
          end,
          taskArgs = function()
            return vim.split(vim.fn.input("args: "), " ", { trimempty = true })
          end,
        }),
      }
      -- Also allow starting the debugger from .heex template buffers.
      dap.configurations.heex = dap.configurations.elixir
    end,
  },
}
