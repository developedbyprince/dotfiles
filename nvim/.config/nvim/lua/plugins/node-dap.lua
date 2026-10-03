-- Node / TypeScript / browser debugging configs on top of LazyVim's js-debug-adapter setup.
-- The typescript extra defines the pwa-node/pwa-chrome adapters; this file replaces
-- its launch configurations with a richer set. User specs load after LazyVim's, so these win.
return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")

      -- Defaults every Node config shares.
      local common = {
        cwd = "${workspaceFolder}",
        sourceMaps = true, -- map compiled JS back to your TS source
        smartStep = true, -- step over generated code that has no source mapping
        skipFiles = { "<node_internals>/**", "**/node_modules/**" }, -- don't step into Node core or deps
        resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" }, -- only trust your maps
        console = "integratedTerminal", -- program output (and stdin) in a terminal split
      }
      local function with(cfg)
        return vim.tbl_extend("force", common, cfg)
      end

      -- Package manager for the current project (pnpm if it has a pnpm lockfile).
      local function pm()
        return vim.fs.root(0, "pnpm-lock.yaml") and "pnpm" or "npm"
      end

      -- Test runner entry point for the current project (vitest preferred, else jest).
      local function test_program()
        local root = vim.fs.root(0, "package.json") or vim.fn.getcwd()
        local vitest = root .. "/node_modules/vitest/vitest.mjs"
        local jest = root .. "/node_modules/jest/bin/jest.js"
        if vim.uv.fs_stat(vitest) then
          return vitest
        end
        if vim.uv.fs_stat(jest) then
          return jest
        end
        vim.notify("No vitest or jest in node_modules", vim.log.levels.ERROR)
        return dap.ABORT
      end

      local node_configs = {
        with({
          type = "pwa-node",
          request = "launch",
          name = "Launch current file",
          program = "${file}",
          -- Node 23.6+ runs .ts files natively (type stripping), so no tsx/ts-node needed.
          runtimeExecutable = "node",
        }),
        with({
          type = "pwa-node",
          request = "launch",
          name = "Launch package.json script",
          runtimeExecutable = pm, -- npm or pnpm
          runtimeArgs = function()
            return { "run", vim.fn.input("script: ", "dev") }
          end,
          autoAttachChildProcesses = true, -- follow child processes (nodemon, next, nest, etc.)
        }),
        with({
          type = "pwa-node",
          request = "launch",
          name = "Debug current test file",
          program = test_program,
          args = function()
            local file = vim.fn.expand("%:p")
            local prog = test_program()
            -- vitest: `run <file>` (no watch); jest: `--runInBand <file>` (single process)
            if type(prog) == "string" and prog:match("vitest") then
              return { "run", file }
            end
            return { "--runInBand", file }
          end,
          autoAttachChildProcesses = true, -- vitest runs tests in worker processes
        }),
        with({
          type = "pwa-node",
          request = "attach",
          name = "Attach to process",
          processId = function() -- pick a running node process
            return require("dap.utils").pick_process({ filter = "node" })
          end,
        }),
        with({
          type = "pwa-node",
          request = "attach",
          name = "Attach to :9229 (node --inspect / Docker)",
          address = "localhost",
          port = 9229, -- default inspector port
          restart = true, -- re-attach automatically when the process restarts (nodemon)
          localRoot = "${workspaceFolder}",
          remoteRoot = function() -- e.g. /app inside a Docker container
            return vim.fn.input("remote root: ", vim.fn.getcwd())
          end,
        }),
      }

      -- Frontend (Vue/React) in Chrome against a running dev server.
      local chrome = {
        type = "pwa-chrome",
        request = "launch",
        name = "Launch Chrome (dev server)",
        url = function() -- Vite's default port
          return vim.fn.input("url: ", "http://localhost:5173")
        end,
        webRoot = "${workspaceFolder}", -- where served files map to on disk
        sourceMaps = true,
        userDataDir = false, -- use a fresh temp profile each time
      }

      for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        dap.configurations[ft] = vim.list_extend(vim.deepcopy(node_configs), { chrome })
      end
      dap.configurations.vue = { chrome } -- debug Vue SFCs in the browser
    end,
  },

  -- Test explorer adapters for Vitest and Jest (each only activates in projects that use it).
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "marilari88/neotest-vitest", "nvim-neotest/neotest-jest" },
    opts = {
      adapters = {
        ["neotest-vitest"] = {},
        ["neotest-jest"] = {},
      },
    },
  },
}
