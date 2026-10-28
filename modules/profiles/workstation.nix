{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.workstation = {
    config,
    pkgs,
    ...
  }: let
    nixosConfig = config;
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    imports = [
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules.anyrun
      self.nixosModules.discord
      self.nixosModules.plasma
      self.nixosModules.rofi
      self.nixosModules.environment
      self.nixosModules.nix
      self.nixosModules.kittySsh
      self.nixosModules.gnupg
      self.nixosModules.fonts
      inputs.temple.nixosModules.temple
    ];
    temple = {
      enable = true;
      terminal = self.packages.${pkgs.stdenv.hostPlatform.system}.terminal;
      keybinds = {
        anyrun = {
          key = "Alt+R";
          command = "anyrun";
        };
        rofi = {
          key = "Alt+Shift+R";
          command = "rofi -show combi";
        };
        rofi-vs = {
          key = "Alt+P";
          command = "rofi -show vs";
        };
        doubletake = {
          key = "Alt+B";
          command = "rofi -show doubletake";
        };
        voxtype = {
          key = "Scroll Lock";
          # command = "voxtype record toggle";
          command = ''sh -c 'voxtype record toggle $([ "$XDG_SESSION_DESKTOP" = temple ] && echo --no-osd)' '';
        };
      };
      activateLinux.enable = true;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = {inherit self;};

    home-manager.sharedModules = [
      self.homeModules.firefox
      self.homeModules.chromium
    ];

    home-manager.users.luc = _: {
      home = {
        username = "luc";
        homeDirectory = "/home/luc";

        stateVersion = nixosConfig.system.stateVersion;
      };
    };

    users.users.luc.packages = with pkgs; [
      tree
      fastfetch
      selfpkgs.frame-sh-wayland
      soapysdr
      hackrf
      soapyhackrf
      gqrx
      sdrangel

      # koi
      obsidian

      sops
      age
      jq
      # Plasma keeps the clipboard in Klipper and ships no CLI for it, so
      # anything reading a selection from a terminal needs this. Claude
      # Code's image paste is one such reader.
      wl-clipboard

      signal-desktop
      telegram-desktop
      mattermost-desktop
      gajim

      tailscale
      netbird

      freelens-bin

      thunderbird
      rpi-imager
      orca-slicer

      obs-studio
      vlc

      libreoffice-qt
    ];

    # https://wiki.nixos.org/wiki/Chromium#Enabling_native_Wayland_support
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      kdePackages.dolphin
      kdePackages.kate
      pkgs.pinentry-qt
      inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.attic
    ];
  };
}
