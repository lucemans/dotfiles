{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.desktop = {
    config,
    pkgs,
    ...
  }: let
    nixosConfig = config;
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
    # koi = inputs.koi.packages.x86_64-linux.default;
  in {
    imports = [
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules.cursor
      self.nixosModules.vscodium
      self.nixosModules.opencode
      self.nixosModules.claude-code
      self.nixosModules.rofi
    ];

    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    # services.xserver.enable = lib.mkDefault true;

    # security.polkit.enable = true;
    # services.upower.enable = lib.mkDefault true;

    # hardware.graphics = {
    #   enable = lib.mkDefault true;
    #   enable32Bit = lib.mkDefault true;
    # };

    # https://wiki.nixos.org/wiki/Chromium#Enabling_native_Wayland_support
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    fonts.packages = with pkgs; [nerd-fonts.hack];
    fonts.fontconfig.defaultFonts.monospace = ["Hack"];

    environment.etc."plasma/start-icon.jpg".source = self.startIcon;

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = {inherit self;};

    home-manager.sharedModules = [
      inputs.plasma-manager.homeModules.plasma-manager
      inputs.sops-nix.homeManagerModules.sops
      self.homeModules.firefox
      self.homeModules.chromium
      self.homeModules.nvim
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
          zed-editor
          gitkraken
          selfpkgs.agentsview
          selfpkgs.agentsview-desktop
          selfpkgs.ethereum-price-plasmoid
          selfpkgs.frame-sh-wayland
          pi-coding-agent
          soapysdr
          hackrf
          soapyhackrf
          gqrx

          # koi

          sops
          age
          jq
          gnupg
          pinentry-qt

          signal-desktop
          telegram-desktop
          mattermost-desktop
          gajim

          (discord.override {
            #withOpenASAR = true;
            withVencord = true;
          })

          spotify
          kubectl

          kicad-unstable
          selfpkgs.kicad-mcp

          tailscale
          netbird
          (lens.overrideAttrs (old: {
            # Electron GPU rendering produces a blank Lens window on NVIDIA Wayland sessions.
            postFixup =
              (old.postFixup or "")
              + ''
                wrapProgram $out/bin/lens-desktop --add-flags "--disable-gpu"
              '';
          }))

          thunderbird
          prismlauncher
          rpi-imager
          orca-slicer

          obs-studio
          vlc

          nil
          nixd
          statix
          alejandra
          manix
          nix-inspect

          sqlite
        ];

        username = "luc";
        homeDirectory = "/home/luc";

        stateVersion = nixosConfig.system.stateVersion;
      };

      home.file.".pi/agent/extensions/kicad-mcp/index.ts".source = ./code/pi/kicad-mcp-extension.ts;

      sops = {
        age.keyFile = "/home/luc/.config/sops/age/keys.txt";
        defaultSopsFile = ../secrets/secrets.sops.yaml;
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

      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.kdePackages.xdg-desktop-portal-kde
        ];
        config.common.default = "*";
      };

      xdg.dataFile."plasma/plasmoids/nl.lucemans.ethereum-price".source = "${selfpkgs.ethereum-price-plasmoid}/share/plasma/plasmoids/nl.lucemans.ethereum-price";

      programs.plasma = {
        enable = true;
        overrideConfig = true;

        workspace = {
          wallpaper = "${self.wallpaper}";
          colorScheme = "BreezeDark";
          theme = "breeze-dark";
          tooltipDelay = 3;
        };

        kscreenlocker = {
          appearance = {
            wallpaper = self.wallpaper;
          };
        };

        hotkeys.commands."launch-konsole" = {
          name = "Launch Konsole";
          key = "Alt+K";
          command = "kitty";
        };

        panels = [
          {
            location = "top";
            screen = 2;
            height = 32;
            floating = false;
            widgets = [
              {
                kickoff = {
                  icon = "/etc/plasma/start-icon.jpg";
                };
              }
              "org.kde.plasma.pager"
              "org.kde.plasma.icontasks"
              "org.kde.plasma.marginsseparator"
              "org.kde.plasma.systemtray"
              {
                name = "nl.lucemans.ethereum-price";
              }
              "org.kde.plasma.digitalclock"
              # "org.kde.plasma.showdesktop"
            ];
          }
        ];
      };

      programs.direnv = {
        enable = true;
        silent = false;
        # loadInNixShell = true;
        # direnvrcExtra = "";
        nix-direnv = {
          enable = true;
        };
      };

      # programs.konsole = {
      #  enable = true;
      #  defaultProfile = "Hack";
      #  profiles."Hack" = {
      #    font = {
      #      name = "Hack";
      #      size = 11;
      #    };
      #  };
      #};

      # home.activation.dolphinDevelop = lib.hm.dag.entryAfter ["writeBoundary"] ''
      #   path="$HOME/.local/share/user-places.xbel"
      #   url="file:///home/luc/dev"
      #   title="Development"
      #   icon="folder-development"

      #   if [ ! -f "$path" ]; then
      #     ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$path")"
      #     printf '%s\n' \
      #       '<?xml version="1.0" encoding="UTF-8"?>' \
      #       '<xbel version="1.0" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks" xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info" xmlns:rk="http://www.freedesktop.org/standards/desktop-bookmarks">' \
      #       '</xbel>' \
      #       > "$path"
      #   fi

      #   if ${pkgs.yq-go}/bin/yq '.xbel.bookmark.[] | select(."+@href" == env(URL))' "$path" -p xml -e >/dev/null 2>&1; then
      #     exit 0
      #   fi

      #   BOOKMARK=${
      #     lib.escapeShellArg (
      #       builtins.toJSON {
      #         "+@href" = "file:///home/luc/dev";
      #         title = "Development";
      #         info.metadata = [
      #           {
      #             "+@owner" = "http://freedesktop.org";
      #             bookmark.icon."+@name" = "folder-development";
      #           }
      #         ];
      #       }
      #     )
      #   } URL="$url" ${pkgs.yq-go}/bin/yq '.xbel.bookmark += env(BOOKMARK)' -i "$path" -p xml -ox
      # '';

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

    environment.systemPackages = with pkgs; [
      kdePackages.dolphin
      kdePackages.kate
      pkgs.pinentry-qt
    ];
  };
}
