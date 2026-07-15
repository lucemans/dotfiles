local capabilities = require("cmp_nvim_lsp").default_capabilities()

local on_attach = function(_, buffer)
  local map = function(keys, action, description)
    vim.keymap.set("n", keys, action, { buffer = buffer, desc = description, silent = true })
  end

  map("gd", vim.lsp.buf.definition, "Go to definition")
  map("gD", vim.lsp.buf.declaration, "Go to declaration")
  map("gi", vim.lsp.buf.implementation, "Go to implementation")
  map("gr", vim.lsp.buf.references, "Go to references")
  map("K", vim.lsp.buf.hover, "Hover documentation")
  map("<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("<leader>de", vim.diagnostic.open_float, "Show diagnostic")
  map("<leader>oi", function()
    vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } } })
  end, "Organize imports")
  map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
end

local configure = function(name, config)
  config.capabilities = capabilities
  config.on_attach = on_attach
  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

for name, config in pairs({
  jsonls = {},
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false },
      },
    },
  },
  marksman = {},
  mdx_analyzer = {},
  nixd = {
    settings = {
      nixd = {
        formatting = {
          command = { "alejandra" },
        },
        nixpkgs = {
          expr = "import <nixpkgs> { }",
        },
      },
    },
  },
  taplo = {
    cmd = { vim.env.TAPLO_LSP, "lsp", "stdio" },
  },
  yamlls = {
    settings = {
      yaml = {
        schemas = {
          ["https://json.schemastore.org/traefik-v3.json"] = {
            "traefik.yaml",
            "traefik.yml",
            "**/traefik.yaml",
            "**/traefik.yml",
          },
          ["https://www.schemastore.org/traefik-v3-file-provider.json"] = {
            "provider-*.yml",
          },
        },
      },
    },
  },
}) do
  configure(name, config)
end

for name, project_server in pairs({
  pyright = { config = {}, executable = "pyright" },
  rust_analyzer = {
    config = {
      settings = {
        ["rust-analyzer"] = {
          check = { command = "clippy" },
        },
      },
    },
    executable = "rust-analyzer",
  },
  ts_ls = { config = {}, executable = "typescript-language-server" },
}) do
  if vim.fn.executable(project_server.executable) == 1 then
    configure(name, project_server.config)
  end
end
