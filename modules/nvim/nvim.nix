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
        {
          plugin = pkgs.vimPlugins.vim-startify;
          # config = "let g:startify_change_to_vcs_root = 0";
        }
      ];
    };
  };
}
