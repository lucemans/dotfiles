{
  config,
  lib,
  pkgs,
  ethereum-nix,
  ...
}:
{
  flake.nixosModules.fighterHome =
    {
      self,
      pkgs,
      lib,
      config,
      ...
    }:
    {
      programs.git = {
        enable = true;
        settings = {
          user = {
            name = "luc";
            email = "luc@lucemans.nl";
          };
          init.defaultBranch = "master";
        };
      };

      programs.firefox = {
        enable = true;
        languagePacks = [ "en-US" "nl" "zh-CN" ];
        preferences = {
          "browser.startup.homepage" = "https://home.v3x.sh";
          "privacy.resistFingerprinting" = true;
        };
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
        # profiles.default.search = {
        #   force = true;
        #   default = "DuckDuckGo";
        #   privateDefault = "DuckDuckGo";

        #   engines = {
        #        "Nix Packages" = {
        #          urls = [
        #            {
        #              template = "https://search.nixos.org/packages";
        #              params = [
        #                { name = "channel"; value = "unstable"; }
        #                { name = "query";   value = "{searchTerms}"; }
        #              ];
        #            }
        #          ];
        #          icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        #          definedAliases = [ "@np" ];
        #        };

        #        "Nix Options" = {
        #          urls = [
        #            {
        #              template = "https://search.nixos.org/options";
        #              params = [
        #                { name = "channel"; value = "unstable"; }
        #                { name = "query";   value = "{searchTerms}"; }
        #              ];
        #            }
        #          ];
        #          icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        #          definedAliases = [ "@no" ];
        #        };

        #        "NixOS Wiki" = {
        #          urls = [
        #            {
        #              template = "https://wiki.nixos.org/w/index.php";
        #              params = [
        #                { name = "search"; value = "{searchTerms}"; }
        #              ];
        #            }
        #          ];
        #          icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        #          definedAliases = [ "@nw" ];
        #        };
        #      };
        # };
      };
    };
}
