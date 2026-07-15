{
  flake.homeModules.nvim = {pkgs, ...}: {
    programs.neovim = {
      enable = true;
      extraConfig = ''
        set number relativenumber
        set undofile
        let &undodir = stdpath('state') . '/undo'
        call mkdir(&undodir, 'p')
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
            local telescope = require('telescope')
            local actions = require('telescope.actions')

            telescope.setup({
              defaults = {
                file_ignore_patterns = {
                  '%.git/',
                  'node_modules/',
                  '%.venv/',
                },
              },
              pickers = {
                find_files = {
                  hidden = true,
                  no_ignore = true,
                },
                live_grep = {
                  additional_args = function()
                    return { '--hidden' }
                  end,
                },
                buffers = {
                  mappings = {
                    n = { d = actions.delete_buffer },
                  },
                },
              },
            })
            telescope.load_extension('fzf')

            vim.keymap.set('n', '<C-f>', require('telescope.builtin').find_files, { silent = true })
            vim.keymap.set('n', '<leader>ff', require('telescope.builtin').find_files, { silent = true })
            vim.keymap.set('n', '<leader>fg', require('telescope.builtin').live_grep, { silent = true })
            vim.keymap.set('n', '<leader>fb', require('telescope.builtin').buffers, { silent = true })
            vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<CR>', { silent = true })
          '';
        }
        {
          plugin = pkgs.vimPlugins.telescope-fzf-native-nvim;
          config = "";
        }
        {
          plugin = pkgs.vimPlugins.vim-startify;
          config = ''
            vim.g.startify_custom_header = {
              '  Keybindings',
              '  Files: <C-f>/<Space>ff find | <Space>fg grep | <Space>fb buffers | <Space>e tree',
              '  Git: ]c/[c hunks | <Space>gb blame | <Space>gp preview',
              '  LSP: gd definition | gr references | K hover | <Space>ca action | <Space>rn rename',
              '  Edit: <Space>f format | <Space>oi organize imports | ss jump | S treesitter jump',
              '  Sessions: <Space>qs save | <Space>qd delete',
            }
            vim.g.startify_lists = {
              { type = 'files', header = { '  Recent files' } },
            }
            vim.g.startify_change_to_vcs_root = 0
          '';
        }
        {
          plugin = pkgs.vimPlugins.flash-nvim;
          config = ''
            vim.keymap.set('n', 'ss', function()
              require('flash').jump()
            end, { silent = true })
            vim.keymap.set('n', 'S', function()
              require('flash').treesitter()
            end, { silent = true })
          '';
        }
        {
          plugin = pkgs.vimPlugins.mini-nvim;
          config = ''
            require('mini.ai').setup()
            require('mini.surround').setup()
            require('mini.indentscope').setup({ symbol = '|' })
            require('mini.sessions').setup({
              autoread = true,
              autowrite = true,
              file = '.session',
              force = { read = false, write = true, delete = true },
            })

            vim.keymap.set('n', '<leader>qs', function()
              require('mini.sessions').write('.session')
            end, { silent = true })
            vim.keymap.set('n', '<leader>qd', function()
              require('mini.sessions').delete('.session')
            end, { silent = true })
          '';
        }
        {
          plugin = pkgs.vimPlugins.lualine-nvim;
          config = ''
            require('lualine').setup({
              options = {
                theme = 'auto',
                globalstatus = true,
              },
              sections = {
                lualine_a = { 'mode' },
                lualine_b = { 'branch', 'diff', 'diagnostics' },
                lualine_c = { 'filename' },
                lualine_x = { 'filetype', 'lsp_status' },
                lualine_y = { 'progress' },
                lualine_z = { 'location' },
              },
            })
          '';
        }
        pkgs.vimPlugins.cmp-buffer
        pkgs.vimPlugins.cmp-nvim-lsp
        pkgs.vimPlugins.cmp-path
        {
          plugin = pkgs.vimPlugins.conform-nvim;
          config = ''
            require('conform').setup({
              format_on_save = function(bufferNumber)
                local filetype = vim.bo[bufferNumber].filetype
                if filetype ~= 'nix' and filetype ~= 'toml' then
                  return
                end

                return { timeout_ms = 2000, lsp_format = 'never' }
              end,
              formatters_by_ft = {
                javascript = { 'eslint_d', 'prettier', stop_after_first = true },
                javascriptreact = { 'eslint_d', 'prettier', stop_after_first = true },
                json = { 'jq' },
                jsonc = { 'prettier' },
                lua = { 'stylua' },
                markdown = { 'prettier' },
                nix = { 'alejandra' },
                python = { 'ruff_format' },
                rust = { 'rustfmt' },
                toml = { 'taplo' },
                typescript = { 'eslint_d', 'prettier', stop_after_first = true },
                typescriptreact = { 'eslint_d', 'prettier', stop_after_first = true },
                yaml = { 'prettier' },
              },
              formatters = {
                jq = {
                  command = "${pkgs.jq}/bin/jq",
                },
                taplo = {
                  command = "${pkgs.taplo}/bin/taplo",
                },
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
              just
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
            vim.api.nvim_create_autocmd('FileType', {
              pattern = {
                'bash',
                'css',
                'html',
                'javascript',
                'javascriptreact',
                'json',
                'jsonc',
                'just',
                'lua',
                'markdown',
                'nix',
                'python',
                'rust',
                'toml',
                'typescript',
                'typescriptreact',
                'vim',
                'yaml',
              },
              callback = function()
                pcall(vim.treesitter.start)
              end,
            })
            require('nvim-treesitter').setup({
              indent = { enable = true },
            })
          '';
        }
        {
          plugin = pkgs.vimPlugins.lazydev-nvim;
          config = ''
            require('lazydev').setup()
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

            local configure_server = function(serverName, serverConfig)
              serverConfig.capabilities = capabilities
              serverConfig.on_attach = on_attach
              vim.lsp.config(serverName, serverConfig)
              vim.lsp.enable(serverName)
            end

            local systemServers = {
              jsonls = {
                cmd = {
                  "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server",
                  '--stdio',
                },
              },
              lua_ls = {},
              marksman = {},
              nixd = {},
              taplo = {
                cmd = {
                  "${pkgs.taplo}/bin/taplo",
                  'lsp',
                  'stdio',
                },
              },
              yamlls = {
                cmd = {
                  "${pkgs.yaml-language-server}/bin/yaml-language-server",
                  '--stdio',
                },
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

            for serverName, serverConfig in pairs(systemServers) do
              configure_server(serverName, serverConfig)
            end

            local projectServers = {
              pyright = {
                executable = 'pyright',
                config = {},
              },
              rust_analyzer = {
                executable = 'rust-analyzer',
                config = {
                  settings = {
                    ['rust-analyzer'] = {
                      check = { command = 'clippy' },
                    },
                  },
                },
              },
              ts_ls = {
                executable = 'typescript-language-server',
                config = {},
              },
            }

            for serverName, projectServer in pairs(projectServers) do
              if vim.fn.executable(projectServer.executable) == 1 then
                configure_server(serverName, projectServer.config)
              end
            end
          '';
        }
      ];
    };
  };
}
