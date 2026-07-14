{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.plasma = {pkgs, ...}: let
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
    };

    environment.etc."plasma/start-icon.jpg".source = self.startIcon;

    home-manager.sharedModules = [
      inputs.plasma-manager.homeModules.plasma-manager
    ];

    home-manager.users.luc = {pkgs, ...}: {
      home.packages = [selfpkgs.ethereum-price-plasmoid];

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

        input.keyboard = {
          layouts = [{layout = "us";}];
          model = "pc104";
          options = ["caps:super"];
          numlockOnStartup = "on";
        };

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
            ];
          }
        ];
      };
    };
  };
}
