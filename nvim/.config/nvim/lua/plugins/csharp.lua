-- C# / .NET: Roslyn LSP (roslyn.nvim), Razor, treesitter, formatting, debugging, tests.
return {
  -- Mason: install the Roslyn server and the CSharpier formatter automatically.
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "roslyn-language-server", "csharpier" } },
  },

  -- Stop LazyVim/mason-lspconfig from auto-starting other C# servers.
  -- Without roslyn_ls = false, the Mason package would also start lspconfig's
  -- roslyn_ls, giving two Roslyn clients per buffer.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        roslyn_ls = { enabled = false }, -- roslyn.nvim manages the server instead
        omnisharp = { enabled = false }, -- guard against the older OmniSharp server
        csharp_ls = { enabled = false }, -- guard against the community csharp-ls
      },
    },
  },

  -- roslyn.nvim: starts Roslyn, finds/selects the .sln/.slnx, handles Razor.
  {
    "seblyng/roslyn.nvim",
    -- Loaded at startup (it's tiny: it only registers the LSP config and :Roslyn).
    -- Lazy-loading on ft would start the server before our settings/opts apply.
    lazy = false,
    opts = {
      filewatching = "auto", -- let Roslyn watch project files itself (faster on big repos)
      broad_search = true, -- look for solutions in parent and child dirs, not just the root
      lock_target = true, -- remember the chosen solution so it does not re-prompt
    },
    config = function(_, opts)
      require("roslyn").setup(opts) -- apply the opts above
    end,
    init = function()
      -- Map .razor and .cshtml files to the "razor" filetype so Roslyn attaches.
      vim.filetype.add({ extension = { razor = "razor", cshtml = "razor" } })

      -- Make the "N references" code lens clickable (<leader>cc): Roslyn sends a
      -- client-side command with the symbol's position; jump there and list references.
      vim.lsp.commands["roslyn.client.peekReferences"] = function(command)
        local uri, pos = command.arguments[1], command.arguments[2]
        if vim.uri_to_bufnr(uri) == vim.api.nvim_get_current_buf() then
          vim.api.nvim_win_set_cursor(0, { pos.line + 1, pos.character })
        end
        if Snacks and Snacks.picker then
          Snacks.picker.lsp_references()
        else
          vim.lsp.buf.references()
        end
      end

      -- Server settings. Registered in init so they exist before the plugin enables
      -- the server. The command is left to roslyn.nvim: it finds Mason's
      -- `roslyn-language-server` and adds its daemon flags.
      vim.lsp.config("roslyn", {
        settings = {
          ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true, -- show type on `new()`
            csharp_enable_inlay_hints_for_implicit_variable_types = true, -- show type on `var`
            csharp_enable_inlay_hints_for_lambda_parameter_types = true, -- show lambda param types
            csharp_enable_inlay_hints_for_types = true, -- master switch for type hints
            csharp_enable_inlay_hints_for_collection_expressions = true, -- show target type on `[1, 2]`
            dotnet_enable_inlay_hints_for_parameters = true, -- show parameter names at call sites
            dotnet_enable_inlay_hints_for_literal_parameters = true, -- ...for literal args like `true`, `5`
            dotnet_enable_inlay_hints_for_object_creation_parameters = true, -- ...for constructor args
            dotnet_enable_inlay_hints_for_indexer_parameters = true, -- ...for indexer args
            dotnet_enable_inlay_hints_for_other_parameters = true, -- ...for everything else
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true, -- hide `name: name`
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true, -- hide `arg1, arg2`
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true, -- hide obvious ones
          },
          ["csharp|code_lens"] = {
            dotnet_enable_references_code_lens = true, -- "N references" above members
            -- Roslyn's "Run/Debug Test" lenses need VS Code's test runner; use neotest (<leader>t) instead.
            dotnet_enable_tests_code_lens = false,
          },
          ["csharp|completion"] = {
            dotnet_show_completion_items_from_unimported_namespaces = true, -- complete + auto-add `using`
            dotnet_show_name_completion_suggestions = true, -- suggest variable names
            dotnet_provide_regex_completions = true, -- completions inside Regex strings
          },
          ["csharp|background_analysis"] = {
            dotnet_compiler_diagnostics_scope = "fullSolution", -- compile errors across the whole solution
            dotnet_analyzer_diagnostics_scope = "openFiles", -- analyzers on open files only (fullSolution is slow)
          },
          ["csharp|symbol_search"] = {
            dotnet_search_reference_assemblies = true, -- workspace symbols include NuGet/BCL types
          },
          ["csharp|formatting"] = {
            dotnet_organize_imports_on_format = true, -- sort/remove `using`s when Roslyn formats
          },
        },
      })
    end,
    keys = {
      -- Buffer-local (ft = cs/razor) so they don't clash elsewhere.
      { "<leader>cT", "<cmd>Roslyn target<cr>", desc = "Roslyn: switch solution", ft = { "cs", "razor" } },
      { "<leader>cX", "<cmd>Roslyn restart<cr>", desc = "Roslyn: restart server", ft = { "cs", "razor" } },
    },
  },

  -- Treesitter parsers for highlighting, folds and textobjects.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "c_sharp", "razor" } },
  },

  -- Formatting: CSharpier only when the project opts in, otherwise Roslyn
  -- (which follows .editorconfig). Avoids reformatting repos that don't use CSharpier.
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        cs = { "csharpier", lsp_format = "fallback" }, -- no csharpier => use Roslyn
      },
      formatters = {
        csharpier = {
          condition = function(_, ctx)
            -- 1) project has a CSharpier config/ignore file somewhere above this file
            local markers = { ".csharpierrc", ".csharpierrc.json", ".csharpierrc.yaml", ".csharpierignore" }
            if vim.fs.root(ctx.dirname, markers) then
              return true
            end
            -- 2) or csharpier is a local dotnet tool in .config/dotnet-tools.json
            local manifest = vim.fs.find(function(name, path)
              return name == "dotnet-tools.json" and path:match("[/\\]%.config$") ~= nil
            end, { upward = true, path = ctx.dirname })[1]
            if manifest then
              local ok, lines = pcall(vim.fn.readfile, manifest)
              return ok and table.concat(lines, "\n"):find('"csharpier"') ~= nil
            end
            return false -- no opt-in: conform falls back to Roslyn formatting
          end,
        },
      },
    },
  },

  -- Native arm64 netcoredbg binary (Mason only ships an Intel build for macOS).
  -- Used only as a binary download: its setup() would overwrite our C# configs,
  -- so we never call it and point the adapter at its binary below instead.
  {
    "Cliffback/netcoredbg-macOS-arm64.nvim",
    cond = vim.fn.has("mac") == 1 and jit.arch == "arm64", -- only on Apple Silicon
    lazy = true, -- never loaded; we only need the files on disk
  },
  -- Stop mason-nvim-dap from auto-installing Mason's Intel-only netcoredbg on Apple Silicon.
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      if not (vim.fn.has("mac") == 1 and jit.arch == "arm64") then
        return
      end
      if type(opts.automatic_installation) ~= "table" then
        opts.automatic_installation = { exclude = {} }
      end
      opts.automatic_installation.exclude = opts.automatic_installation.exclude or {}
      table.insert(opts.automatic_installation.exclude, "coreclr")
    end,
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")

      -- netcoredbg binary: the arm64 build on Apple Silicon, Mason's elsewhere.
      local arm64 = LazyVim.get_plugin_path("netcoredbg-macOS-arm64.nvim", "netcoredbg/netcoredbg")
      local netcoredbg = (arm64 and vim.uv.fs_stat(arm64)) and arm64 or vim.fn.exepath("netcoredbg")
      local adapter = {
        type = "executable",
        command = netcoredbg,
        args = { "--interpreter=vscode" }, -- speak the VS Code debug protocol
      }
      dap.adapters.coreclr = adapter -- name used by VS Code launch.json files
      dap.adapters.netcoredbg = adapter -- name some plugins expect

      -- Read KEY=VALUE pairs from a .env file next to the project, if present.
      local function dotenv(dir)
        local env = {}
        local path = dir and vim.fs.joinpath(dir, ".env")
        if not (path and vim.uv.fs_stat(path)) then
          return env
        end
        for _, line in ipairs(vim.fn.readfile(path)) do
          local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
          if k then
            env[k] = v:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
          end
        end
        return env
      end

      -- Directory of the nearest .csproj above the current buffer.
      local function project_dir()
        return vim.fs.root(0, function(name)
          return name:match("%.csproj$") ~= nil
        end)
      end

      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Launch project (build first)",
          request = "launch",
          program = function()
            local dir = project_dir()
            if not dir then
              vim.notify("No .csproj found", vim.log.levels.ERROR)
              return dap.ABORT
            end
            -- Build before launching so the debugger runs current code.
            vim.notify("dotnet build " .. dir, vim.log.levels.INFO)
            local res = vim.system({ "dotnet", "build", dir, "-c", "Debug" }, { text = true }):wait()
            if res.code ~= 0 then
              vim.notify("dotnet build failed:\n" .. (res.stdout or ""), vim.log.levels.ERROR)
              return dap.ABORT
            end
            -- Project name = .csproj file name; dll lives at bin/Debug/<tfm>/<name>.dll.
            local csproj = vim.fn.glob(dir .. "/*.csproj", false, true)[1]
            local name = vim.fn.fnamemodify(csproj, ":t:r")
            local dlls = vim.fn.glob(dir .. "/bin/Debug/*/" .. name .. ".dll", false, true)
            -- Pick the most recently built dll if multiple target frameworks exist.
            table.sort(dlls, function(a, b)
              return vim.fn.getftime(a) > vim.fn.getftime(b)
            end)
            return dlls[1] or dap.ABORT
          end,
          cwd = function() -- run from project dir so appsettings.json is found
            return project_dir() or vim.fn.getcwd()
          end,
          env = function()
            -- Dev defaults, overridden by the project's .env (project dir or cwd).
            local dir = project_dir()
            return vim.tbl_extend("force", {
              ASPNETCORE_ENVIRONMENT = "Development", -- ASP.NET Core dev settings
              DOTNET_ENVIRONMENT = "Development", -- generic host dev settings
            }, dotenv(vim.fn.getcwd()), dotenv(dir))
          end,
          stopAtEntry = false, -- don't pause on Main(); only stop at breakpoints
        },
        {
          type = "coreclr",
          name = "Attach to process",
          request = "attach",
          processId = function() -- fuzzy-pick a running process
            return require("dap.utils").pick_process()
          end,
        },
      }
    end,
  },

  -- Test explorer adapter for xUnit/NUnit/MSTest via `dotnet test`.
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "Nsidorenco/neotest-vstest" },
    opts = {
      adapters = {
        ["neotest-vstest"] = {
          dap_settings = { type = "coreclr" }, -- debug tests with our arm64 netcoredbg adapter
        },
      },
    },
  },
}
