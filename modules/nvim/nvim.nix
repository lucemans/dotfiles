{
  flake.homeModules.nvim = {pkgs, ...}: {
    programs.neovim = {
      enable = true;
      extraConfig = ''
        set number relativenumber
      '';
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      extraPackages = [
        pkgs.alejandra
        pkgs.fd
        pkgs.lua-language-server
        pkgs.marksman
        pkgs.nixd
        pkgs.prettier
        pkgs.pyright
        pkgs.python3
        pkgs.ruff
        pkgs.rust-analyzer
        pkgs.rustfmt
        pkgs.stylua
        pkgs.taplo
        pkgs.typescript-language-server
        pkgs.vscode-langservers-extracted
        pkgs.yaml-language-server
      ];
      plugins = [
        {
          plugin = pkgs.vimPlugins.nvim-tree-lua;
          config = ''
            vim.g.loaded_netrw = 1
            vim.g.loaded_netrwPlugin = 1
            vim.opt.termguicolors = true
            require("nvim-tree").setup{
              sort = { sorter = "case_sensitive" },
              view = { width = 30 },
              renderer = { group_empty = true },
              filters = { dotfiles = true },
            }
            vim.keymap.set('n', '<C-n>', ':NvimTreeToggle<CR>', { silent = true })
            vim.keymap.set('n', '<leader>e', ':NvimTreeFindFile<CR>', { silent = true })
            vim.keymap.set('n', '<leader>r', ':NvimTreeRefresh<CR>', { silent = true })
          '';
        }
        pkgs.vimPlugins.nvim-web-devicons
        pkgs.vimPlugins.plenary-nvim
        {
          plugin = pkgs.vimPlugins.telescope-nvim;
          config = ''
            vim.keymap.set('n', '<C-f>', require('telescope.builtin').find_files, { silent = true })
          '';
        }
        {
          plugin = pkgs.vimPlugins.vim-startify;
          # config = "let g:startify_change_to_vcs_root = 0";
        }
        pkgs.vimPlugins.cmp-buffer
        pkgs.vimPlugins.cmp-nvim-lsp
        pkgs.vimPlugins.cmp-path
        {
          plugin = pkgs.vimPlugins.conform-nvim;
          config = ''
            require('conform').setup({
              format_on_save = function(bufferNumber)
                if vim.bo[bufferNumber].filetype ~= 'nix' then
                  return
                end

                return { timeout_ms = 2000, lsp_format = 'never' }
              end,
              formatters_by_ft = {
                javascript = { 'prettier' },
                javascriptreact = { 'prettier' },
                json = { 'prettier' },
                jsonc = { 'prettier' },
                lua = { 'stylua' },
                markdown = { 'prettier' },
                nix = { 'alejandra' },
                python = { 'ruff_format' },
                rust = { 'rustfmt' },
                toml = { 'taplo' },
                typescript = { 'prettier' },
                typescriptreact = { 'prettier' },
                yaml = { 'prettier' },
              },
            })
          '';
        }
        {
          plugin = pkgs.vimPlugins.gitsigns-nvim;
          config = ''
            require('gitsigns').setup({
              on_attach = function(bufferNumber)
                local gitsigns = require('gitsigns')
                local map = function(keys, action)
                  vim.keymap.set('n', keys, action, { buffer = bufferNumber, silent = true })
                end

                map(']c', gitsigns.next_hunk)
                map('[c', gitsigns.prev_hunk)
                map('<leader>gb', gitsigns.blame_line)
                map('<leader>gp', gitsigns.preview_hunk)
              end,
            })
          '';
        }
        {
          plugin = pkgs.vimPlugins.nvim-cmp;
          config = ''
            local cmp = require('cmp')
            cmp.setup({
              mapping = cmp.mapping.preset.insert({
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<C-j>'] = cmp.mapping.select_next_item(),
                ['<C-k>'] = cmp.mapping.select_prev_item(),
                ['<CR>'] = cmp.mapping.confirm({ select = true }),
              }),
              sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'path' },
                { name = 'buffer' },
              }),
            })
          '';
        }
        {
          plugin = pkgs.vimPlugins.nvim-treesitter.withPlugins (plugins:
            with plugins; [
              bash
              css
              html
              javascript
              json
              lua
              markdown
              markdown_inline
              nix
              python
              regex
              rust
              toml
              tsx
              typescript
              vim
              vimdoc
              yaml
            ]);
          config = ''
            require('nvim-treesitter').setup({})
            vim.api.nvim_create_autocmd('FileType', {
              callback = function()
                pcall(vim.treesitter.start)
                vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
              end,
            })
          '';
        }
        {
          plugin = pkgs.vimPlugins.nvim-lspconfig;
          config = ''
            local capabilities = require('cmp_nvim_lsp').default_capabilities()

            local on_attach = function(_, bufferNumber)
              local map = function(keys, action)
                vim.keymap.set('n', keys, action, { buffer = bufferNumber, silent = true })
              end

              map('gd', vim.lsp.buf.definition)
              map('gD', vim.lsp.buf.declaration)
              map('gi', vim.lsp.buf.implementation)
              map('gr', vim.lsp.buf.references)
              map('K', vim.lsp.buf.hover)
              map('<leader>ca', vim.lsp.buf.code_action)
              map('<leader>de', vim.diagnostic.open_float)
              map('<leader>f', function()
                require('conform').format({ async = true, lsp_format = 'never' })
              end)
              map('<leader>oi', function()
                vim.lsp.buf.code_action({ context = { only = { 'source.organizeImports' } } })
              end)
              map('<leader>rn', vim.lsp.buf.rename)
            end

            vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { silent = true })
            vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { silent = true })

            local servers = {
              jsonls = {},
              lua_ls = {},
              marksman = {},
              nixd = {},
              pyright = {},
              rust_analyzer = {
                settings = {
                  ['rust-analyzer'] = {
                    check = { command = 'clippy' },
                  },
                },
              },
              taplo = {},
              ts_ls = {},
              yamlls = {
                settings = {
                  yaml = {
                    schemas = {
                      ['https://json.schemastore.org/traefik-v3.json'] = {
                        'traefik.yaml',
                        'traefik.yml',
                        '**/traefik.yaml',
                        '**/traefik.yml',
                      },
                      ['https://www.schemastore.org/traefik-v3-file-provider.json'] = {
                        'provider-*.yml',
                      },
                    },
                  },
                },
              },
            }

            for serverName, serverConfig in pairs(servers) do
              serverConfig.capabilities = capabilities
              serverConfig.on_attach = on_attach
              vim.lsp.config(serverName, serverConfig)
              vim.lsp.enable(serverName)
            end
          '';
        }
      ];
    };
  };
}
