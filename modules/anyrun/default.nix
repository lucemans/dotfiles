{self, ...}: {
  perSystem = {pkgs, ...}: let
    mkPlugin = crateName:
      pkgs.rustPlatform.buildRustPackage {
        pname = "anyrun-plugin-${crateName}";
        version = "0.1.0";
        src = ./plugins + "/${crateName}";
        cargoLock = {
          lockFile = ./plugins + "/${crateName}/Cargo.lock";
          outputHashes = {
            "anyrun-interface-25.12.0" = "sha256-zcKI1OUg+Ukst0nasodrhKgBi61XT8vbvdK6/nuuApk=";
            "anyrun-macros-26.6.1" = "sha256-+Fx+JfSboBk8KKVgmaMKDKvMe9c3WC+7RKYjnpvMVpg=";
            "anyrun-plugin-26.6.1" = "sha256-+Fx+JfSboBk8KKVgmaMKDKvMe9c3WC+7RKYjnpvMVpg=";
          };
        };
        installPhase = ''
          mkdir -p $out/lib
          cp target/*-linux-gnu/release/lib${pkgs.lib.replaceStrings ["-"] ["_"] crateName}.so $out/lib/
        '';
      };
  in {
    packages.anyrun-plugin-ethereum-search = mkPlugin "ethereum-search";
    packages.anyrun-plugin-github = mkPlugin "github";
  };

  flake.nixosModules.anyrun = {pkgs, ...}: let
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    home-manager.users.luc = {
      programs.anyrun = {
        enable = true;
        config = {
          x.fraction = 0.5;
          y.fraction = 0.3;
          width.fraction = 0.35;
          hideIcons = false;
          ignoreExclusiveZones = false;
          layer = "overlay";
          hidePluginInfo = true;
          closeOnClick = true;
          showResultsImmediately = true;
          maxEntries = 10;
          plugins = [
            "${pkgs.anyrun}/lib/libapplications.so"
            "${pkgs.anyrun}/lib/librink.so"
            "${pkgs.anyrun}/lib/libshell.so"
            "${pkgs.anyrun}/lib/libsymbols.so"
            "${pkgs.anyrun}/lib/libwebsearch.so"
            "${pkgs.anyrun}/lib/libnix_run.so"
            "${selfpkgs.anyrun-plugin-ethereum-search}/lib/libethereum_search.so"
            "${selfpkgs.anyrun-plugin-github}/lib/libgithub.so"
          ];
        };
        extraCss = with self.theme; ''
          * {
            font-family: "Hack Nerd Font", "Hack", monospace;
            font-size: 14px;
          }

          window {
            background: transparent;
          }

          .main {
            background: ${base00};
            color: ${base06};
            border: 1px solid ${base02};
            border-radius: 12px;
            padding: 10px;
          }

          text {
            background: ${base01};
            color: ${base07};
            caret-color: ${base0A};
            border-radius: 8px;
            padding: 12px 16px;
            font-size: 18px;
            margin-bottom: 8px;
          }

          text selection {
            background: ${base0D};
            color: ${base00};
          }

          .match {
            padding: 6px 8px;
            border-radius: 8px;
          }

          .match:selected {
            background: ${base01};
          }

          .match .title {
            color: ${base06};
          }

          .match:selected .title {
            color: ${base0B};
          }

          .match .description {
            color: ${base04};
          }

          .plugin .info {
            color: ${base0D};
          }
        '';
      };

      programs.plasma.hotkeys.commands."launch-anyrun" = {
        name = "Launch Anyrun";
        key = "Alt+R";
        command = "anyrun";
      };
    };
  };
}
