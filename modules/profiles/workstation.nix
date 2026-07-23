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
    ];

    fonts.packages = with pkgs; [nerd-fonts.hack];
    fonts.fontconfig.defaultFonts.monospace = ["Hack"];

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = {inherit self;};

    home-manager.sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
      self.homeModules.firefox
      self.homeModules.chromium
    ];

    home-manager.users.luc = {
      self,
      pkgs,
      config,
      ...
    }: {
      home = {
        packages = with pkgs; [
          tree
          fastfetch
          selfpkgs.frame-sh-wayland
          soapysdr
          hackrf
          soapyhackrf
          gqrx

          # koi
          obsidian

          sops
          age
          jq
          gnupg
          pinentry-qt

          signal-desktop
          telegram-desktop
          mattermost-desktop
          gajim

          tailscale
          netbird

          lens

          thunderbird
          rpi-imager
          orca-slicer

          obs-studio
          vlc
        ];

        username = "luc";
        homeDirectory = "/home/luc";

        stateVersion = nixosConfig.system.stateVersion;
      };

      sops = {
        age.keyFile = "/home/luc/.config/sops/age/keys.txt";
        defaultSopsFile = ../../secrets/secrets.sops.yaml;
        secrets = {
          ssh-public-key = {
            path = "/home/luc/.ssh/id_ed25519.pub";
            mode = "0644";
          };
          ssh-private-key = {
            path = "/home/luc/.ssh/id_ed25519";
            mode = "0600";
          };
          crates-io-token = {};
          npm-token = {};
        };
        templates = {
          cargo-credentials = {
            content = ''
              [registry]
              token = "${config.sops.placeholder.crates-io-token}"
            '';
            path = "/home/luc/.cargo/credentials.toml";
            mode = "0600";
          };
          npmrc = {
            content = ''
              //registry.npmjs.org/:_authToken=${config.sops.placeholder.npm-token}
            '';
            path = "/home/luc/.npmrc";
            mode = "0600";
          };
        };
      };

      programs.gpg = {
        enable = true;
      };

      services.gpg-agent = {
        enable = true;
        pinentry.package = pkgs.pinentry-qt;
      };

      services.ssh-agent = {
        enable = false;
      };
    };

    # https://wiki.nixos.org/wiki/Chromium#Enabling_native_Wayland_support
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      kdePackages.dolphin
      kdePackages.kate
      pkgs.pinentry-qt
    ];
  };
}
