{...}: {
  imports = [
    ./agentsview.nix
    ./vscode
    ./pi
    ./opencode
    ./mcp
    ./claude
  ];

  flake.nixosModules.code = {
    self,
    pkgs,
    ...
  }: let
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    imports = [
      self.nixosModules.cursor
      self.nixosModules.vscodium
      self.nixosModules.mcp
      self.nixosModules.opencode
      self.nixosModules.claude-code
    ];

    systemd.tmpfiles.rules = [
      "d /home/luc/dev 0755 luc users -"
      "d /home/luc/dev/local 0755 luc users -"
      "d /home/luc/dev/archive 0755 luc users -"
      "d /home/luc/dev/demo 0755 luc users -"
    ];

    system.activationScripts.developDirectory = ''
      ${pkgs.coreutils}/bin/mkdir -p /home/luc/dev
      ${pkgs.coreutils}/bin/cat > /home/luc/dev/.directory <<'EOF'
      [Desktop Entry]
      Type=Directory
      Icon=folder-development
      EOF
      ${pkgs.coreutils}/bin/chown luc:users /home/luc/dev/.directory
      ${pkgs.coreutils}/bin/chmod 0644 /home/luc/dev/.directory
    '';

    environment.systemPackages = [pkgs.android-tools];

    home-manager.users.luc = {pkgs, ...}: {
      home.packages = [
        pkgs.zed-editor
        pkgs.gitkraken
        selfpkgs.agentsview
        selfpkgs.agentsview-desktop
        pkgs.pi-coding-agent
        pkgs.kubectl
        pkgs.kicad-unstable
        selfpkgs.kicad-mcp
        pkgs.sqlite
      ];

      home.file.".pi/agent/extensions/kicad-mcp/index.ts".source = ./pi/kicad-mcp-extension.ts;

      programs.direnv = {
        enable = true;
        silent = false;
        nix-direnv.enable = true;
      };

      programs.git = {
        enable = true;
        settings = {
          user = {
            name = "Luc";
            email = "luc@lucemans.nl";
          };
          init.defaultBranch = "master";
        };
      };
    };
  };
}
