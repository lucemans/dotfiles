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
    inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) environment terminal;
    editor = lib.getExe pkgs.neovim;
  in {
    environment.systemPackages = [
      terminal
      environment
      pkgs.bash-completion
      pkgs.bat
      pkgs.fzf
      pkgs.ripgrep
      pkgs.zoxide
    ];

    environment.sessionVariables = {
      EDITOR = editor;
      TERMINAL = lib.getExe terminal;
    };

    programs.bash = {
      enable = true;
      completion = {
        enable = true;
      };

      shellAliases = {
        ".." = "cd ..";
        "upgrade" = "sudo nixos-rebuild switch --flake /etc/nixos#v3x-fighter";
      };

      shellInit = ''
        set -o vi
        shopt -s histappend
        shopt -s checkwinsize

        export EDITOR=nvim
        export VISUAL=nvim
        export PAGER=less
      '';
      promptInit = ''
        PS1='\n\[\e[1;37m\]\w\[\e[0m\]\n\[\e[1;32m\]λ\[\e[0m\] '
      '';
    };

    programs.bat.enable = true;

    programs.zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    users.users.luc = {
      shell = lib.mkForce "${environment}/bin/zsh";
    };
  };
}
