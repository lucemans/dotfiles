{
  lib,
  inputs,
  self,
  ...
}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: let
    neovim = pkgs.neovim;
  in {
    packages.terminal =
      (inputs.wrappers.wrapperModules.kitty.apply {
        inherit pkgs;
        imports = [self.wrappersModules.kitty];
        shell = lib.getExe self'.packages.environment;
      }).wrapper;

    packages.environment = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = self'.packages.zsh;
      runtimeInputs = [
        # nix
        pkgs.nil
        pkgs.nixd
        pkgs.statix
        pkgs.alejandra
        pkgs.manix
        pkgs.nix-inspect
        pkgs.nh

        # other
        pkgs.file
        pkgs.unzip
        pkgs.zip
        pkgs.p7zip
        pkgs.wget
        pkgs.killall
        pkgs.sshfs
        pkgs.fzf
        pkgs.htop
        pkgs.btop
        pkgs.eza
        pkgs.fd
        pkgs.zoxide
        pkgs.dust
        pkgs.ripgrep
        pkgs.fastfetch
        pkgs.tree-sitter
        pkgs.imagemagick
        pkgs.imv
        pkgs.ffmpeg-full
        pkgs.yt-dlp
        pkgs.lazygit
        neovim
        pkgs.git
        self'.packages.nix-check-bin
      ];
      env = {
        EDITOR = lib.getExe neovim;
      };
    };

    packages.nix-check-bin = pkgs.writeShellApplication {
      name = "nix-check-bin";
      text = ''
        $EDITOR "$(nix build "$1" --no-link --print-out-paths)/bin"
      '';
    };
  };

  flake.nixosModules.environment = {
    config,
    pkgs,
    self,
    lib,
    ...
  }: let
    inherit (self.packages.${pkgs.system}) environment terminal;
    editor = lib.getExe pkgs.neovim;
  in {
    environment.systemPackages = [
      terminal
      environment
    ];

    environment.sessionVariables = {
      EDITOR = editor;
      TERMINAL = lib.getExe terminal;
    };

    users.users.luc = {
      shell = lib.mkForce "${environment}/bin/zsh";
    };
  };
}
