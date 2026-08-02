{inputs, ...}: {
  flake.nixosModules.launchpi = {config, ...}: {
    imports = [
      inputs.launchpi.nixosModules.default
    ];

    sops = {
      age.keyFile = "/home/luc/.config/sops/age/keys.txt";
      defaultSopsFile = ../../../secrets/secrets.sops.yaml;
      secrets = {
        launchpi_discord_token = {
          owner = "launchpi";
          group = "launchpi";
          mode = "0400";
        };
        launchpi_hass_token = {
          owner = "launchpi";
          group = "launchpi";
          mode = "0400";
        };
      };
    };

    services.launchpi = {
      enable = true;
      host = "127.0.0.1";
      port = 7778;
      # openFirewall = false;
      discovery = true;
      settings = {
        devices = [
          {
            enable = true;
            surface_id = "network-dock";
            name = "Stream Deck Network Dock 0391A2";
            host = "10.90.0.15";
            port = 5343;
            model = "Stream Deck Network Dock";
          }
          {
            enable = true;
            surface_id = "stream-deck-studio";
            name = "Stream Deck Studio 025912";
            host = "10.0.0.195";
            port = 5343;
            model = "Stream Deck Studio";
          }
        ];

        panels = [
          ./studio_main.toml
          ./xl_main.toml
          ./xl_test.toml
          ./subpanel_discord.toml
        ];

        plugins = {
          "discord.default" = {
            enabled = true;
            display_name = "V3X Discord";
            config = {
              user_id = "389006437613043712";
              channel_id = "855458625220378665";
              guild_id = "819404956259057714";
              max_members = 6;
              token.file = config.sops.secrets.launchpi_discord_token.path;
            };
          };
          "hass.default" = {
            enabled = true;
            config = {
              url = "https://hass.v3x.sh";
              token.file = config.sops.secrets.launchpi_hass_token.path;
            };
          };
          "prometheus.default" = {
            enabled = true;
            display_name = "Price Indexer";
            config = {
              target = "https://price.indexer.rs";
              path = "/metrics";
              scrape_interval_s = 60;
            };
          };
        };
      };
    };
  };
}
