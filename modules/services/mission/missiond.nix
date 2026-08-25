{inputs, ...}: {
  flake.nixosModules.missionDisplay = {
    config,
    pkgs,
    ...
  }: {
    imports = [inputs.missiond.nixosModules.default];

    sops.secrets.missiond_admin_key = {
      owner = "luc";
      mode = "0400";
    };

    services.missiond = {
      enable = true;
      user = "luc";
      host = "0.0.0.0";
      openFirewall = true;
      adminKeyFile = config.sops.secrets.missiond_admin_key.path;

      # A systemd unit does not inherit the user's PATH, and the display commands
      # are run by name rather than by store path.
      extraPackages = [
        config.programs.niri.package
        pkgs.ddcutil
      ];

      settings = {
        name = "Mission";
        device_id = "v3x-mission";

        chromium.binary_path = "${pkgs.chromium}/bin/chromium";

        display = {
          output = "DP-1";
          schedule = [
            {
              days = ["mon" "tue" "wed" "thu" "fri"];
              from = "09:00";
              to = "04:00";
            }
          ];
        };

        tabs = {
          grafana-overview = {
            name = "Overview";
            url = "http://127.0.0.1:3001/d/mission-overview/?kiosk&autofitpanels";
          };
          homelab-uptime = {
            name = "Uptime";
            url = "http://127.0.0.1:3001/d/homelab-uptime/?kiosk&autofitpanels";
          };
          indexer-prices = {
            name = "Prices";
            url = "http://127.0.0.1:3001/d/indexer-prices/?kiosk&autofitpanels";
          };
        };

        playlists.mission-display = {
          name = "Mission Display";
          interval = "1m";
          hold = "5m";
          is_default = true;
          tabs = ["grafana-overview" "homelab-uptime" "indexer-prices"];
        };
      };
    };
  };
}
