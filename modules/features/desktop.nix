{ self, inputs, ... }:
{
  flake.nixosModules.desktop =
    { config, pkgs, lib, ... }: let nixosConfig = config; in
  {
    imports = [
      inputs.home-manager.nixosModules.home-manager
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

    # environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.etc."plasma/start-icon.jpg".source = self.startIcon;

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = { inherit self; };

    home-manager.sharedModules = [
      inputs.plasma-manager.homeModules.plasma-manager
      inputs.sops-nix.homeManagerModules.sops
    ];

    home-manager.users.luc =
      { self, pkgs, lib, config, ... }:
      {
        home = {
          packages = with pkgs; [];

          username = "luc";
          homeDirectory = "/home/luc";

          stateVersion = nixosConfig.system.stateVersion;
        };

        sops = {
          age.keyFile = "/home/luc/.config/sops/age/keys.txt";
          defaultSopsFile = ../secrets/secrets.yaml;
          secrets = {
            ssh-public-key = {
              path = "/home/luc/.ssh/id_ed25519.pub";
              mode = "0644";
            };
            ssh-private-key = {
              path = "/home/luc/.ssh/id_ed25519";
              mode = "0600";
            };
            crates-io-token = { };
            npm-token = { };
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

        # home.activation.dolphinDevelop = lib.hm.dag.entryAfter ["writeBoundary"] ''
        #   path="$HOME/.local/share/user-places.xbel"
        #   url="file:///develop"
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
        #         "+@href" = "file:///develop";
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

        programs.plasma = {
          enable = true;
          overrideConfig = true;

          workspace = {
            wallpaper = "${self.wallpaper}";
            colorScheme = "BreezeDark";
            theme = "breeze-dark";
            tooltipDelay = 3;
          };

          hotkeys.commands."launch-konsole" = {
            name = "Launch Konsole";
            key = "Alt+K";
            command = "konsole";
          };

          panels = [
            {
              location = "top";
              screen = 2;
              height = 32;
              floating = false;
          #     widgets = [
          #       {
          #         kickoff = {
          #           icon = "/etc/plasma/start-icon.jpg";
          #         };
          #       }
          #       "org.kde.plasma.pager"
          #       "org.kde.plasma.icontasks"
          #       "org.kde.plasma.marginsseparator"
          #       "org.kde.plasma.systemtray"
          #       "org.kde.plasma.digitalclock"
          #       "org.kde.plasma.showdesktop"
          #     ];
            }
          ];
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

        programs.firefox = {
          enable = true;
          languagePacks = [ "en-US" "nl" "zh-CN" ];
          # preferences = {
          #   "browser.startup.homepage" = "https://home.v3x.sh";
          #   "privacy.resistFingerprinting" = true;
          # };
          policies = {
            AppAutoUpdate = false;
            BackgroundAppUpdate = false;
            DisableBuiltinPDFViewer = true;
            DisableFirefoxStudies = true;
            DisableFirefoxAccounts = true;
            DisableFirefoxScreenshots = true;
            DisableForgetButton = true;
            DisableMasterPasswordCreation = true;
            DisableProfileImport = true;
            DisableProfileRefresh = true;
            DisableSetDesktopBackground = true;
            DisablePocket = true;
            DisablePasswordReveal = true;
            DisableTelemetry = true;

            BlockAboutConfig = false;
            BlockAboutProfiles = true;
            BlockAboutSupport = true;

            DisplayMenuBar = "never";
            DontCheckDefaultBrowser = true;
            OfferToSaveLogins = false;
            DefaultDownloadDirectory = "/home/luc/Downloads";
          };
          profiles.default.search = {
            force = true;
            default = "ddg";
            privateDefault = "ddg";

            engines = {
                 "Nix Packages" = {
                   urls = [
                     {
                       template = "https://search.nixos.org/packages";
                       params = [
                         { name = "channel"; value = "unstable"; }
                         { name = "query";   value = "{searchTerms}"; }
                       ];
                     }
                   ];
                   icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                   definedAliases = [ "@np" ];
                 };

                 "Nix Options" = {
                   urls = [
                     {
                       template = "https://search.nixos.org/options";
                       params = [
                         { name = "channel"; value = "unstable"; }
                         { name = "query";   value = "{searchTerms}"; }
                       ];
                     }
                   ];
                   icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                   definedAliases = [ "@no" ];
                 };

                 "NixOS Wiki" = {
                   urls = [
                     {
                       template = "https://wiki.nixos.org/w/index.php";
                       params = [
                         { name = "search"; value = "{searchTerms}"; }
                       ];
                     }
                   ];
                   icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                   definedAliases = [ "@nw" ];
                 };
               };
          };
        };
      };

    environment.systemPackages = with pkgs; [
      kdePackages.dolphin
      kdePackages.kate
    ];
  };
}
