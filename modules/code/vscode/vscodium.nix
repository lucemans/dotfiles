{
  flake.nixosModules.vscodium = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      vscodium
    ];

    home-manager.users.luc.programs.vscodium = {
      enable = true;
      package = pkgs.vscodium;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        yzhang.markdown-all-in-one
        jnoortheen.nix-ide
        kamadorueda.alejandra
        tamasfe.even-better-toml
        dbaeumer.vscode-eslint
        github.github-vscode-theme
        unifiedjs.vscode-mdx
        rust-lang.rust-analyzer
        vscode-icons-team.vscode-icons
        # remcohaszing.schemastore
      ];
    };

    home-manager.users.luc.home.file.".config/VSCodium/User/settings.json".source = ./settings.json;
    home-manager.users.luc.home.file.".config/VSCodium/User/keybindings.json".source = ./keybindings.json;
  };
}
