{...}: {
  flake.nixosModules.television = {pkgs, ...}: let
    nixpkgs-search = pkgs.writeShellApplication {
      name = "nixpkgs-search";
      runtimeInputs = [
        pkgs.curl
        pkgs.coreutils
        pkgs.jq
        pkgs.television
      ];
      text = builtins.readFile ./nixpkgs-search.sh;
    };
  in {
    home-manager.users.luc = {
      home = {
        packages = [
          nixpkgs-search
          pkgs.television
        ];
        file.".config/television/config.toml".text = ''
          default_channel = "files"
          history_size = 500

          [ui]
          theme = "tokyonight"
          ui_scale = 90

          [ui.preview_panel]
          hidden = true

          [ui.help_panel]
          hidden = true
        '';
      };

      programs.plasma.hotkeys.commands."search-nixpkgs" = {
        name = "Search Nixpkgs";
        key = "Alt+Shift+N";
        command = "${pkgs.kitty}/bin/kitty --title=Nixpkgs-Search ${nixpkgs-search}/bin/nixpkgs-search";
      };
    };
  };
}
