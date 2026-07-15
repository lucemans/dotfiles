{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    treesitter = builtins.removeAttrs (pkgs.vimPlugins.nvim-treesitter.withPlugins (plugins:
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
      ])) ["__ignoreNulls"];
  in {
    packages.neovim = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;

      settings.config_directory = ./.;

      runtimePkgs = [
        pkgs.fd
        pkgs.lua-language-server
        pkgs.marksman
        pkgs.mdx-language-server
        pkgs.nixd
        pkgs.typescript-language-server
        pkgs.vscode-langservers-extracted
        pkgs.yaml-language-server
      ];

      env.TAPLO_LSP = "${pkgs.taplo}/bin/taplo";

      specs = {
        init = {
          data = null;
          before = ["MAIN_INIT"];
          config = "require('config')";
        };

        plugins.data = with pkgs.vimPlugins; [
          cmp-buffer
          cmp-nvim-lsp
          cmp-path
          conform-nvim
          flash-nvim
          gitsigns-nvim
          lazydev-nvim
          lualine-nvim
          mini-nvim
          nvim-cmp
          nvim-lspconfig
          nvim-tree-lua
          treesitter
          nvim-web-devicons
          plenary-nvim
          telescope-fzf-native-nvim
          telescope-nvim
          vim-startify
        ];
      };
    };
  };
}
