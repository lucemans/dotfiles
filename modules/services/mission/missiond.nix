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

    sops.secrets.rtsp_front_door = {
      owner = "luc";
      mode = "0400";
    };

    sops.secrets.missiond_ics_ef = {
      owner = "luc";
      mode = "0400";
    };
    sops.secrets.missiond_ics_ef_protocol = {
      owner = "luc";
      mode = "0400";
    };
    sops.secrets.missiond_ics_v3x = {
      owner = "luc";
      mode = "0400";
    };
    sops.secrets.missiond_ics_personal = {
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
        pkgs.grim
        pkgs.mpv
      ];

      settings = {
        # name = "Mission";
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

          front-door = {
            rtsp.file = config.sops.secrets.rtsp_front_door.path;
            stinger = "doorbell";
          };
        };

        notifications.stingers.doorbell = {
          file = "doorbell.webm";
          max_duration = "2500ms";
        };

        media = {
          "doorbell.webm" = "/home/luc/doorbell.webm";
        };

        calendars = {
          ef = {
            name = "EF";
            url.file = config.sops.secrets.missiond_ics_ef.path;
            window = "12h";
            leads = ["5m" "0s"];
          };
          ef_protocol = {
            name = "EF Protocol";
            url.file = config.sops.secrets.missiond_ics_ef_protocol.path;
            window = "12h";
            leads = ["5m" "0s"];
          };
          v3x = {
            name = "V3X";
            url.file = config.sops.secrets.missiond_ics_v3x.path;
            window = "12h";
            leads = ["5m" "0s"];
          };
          personal = {
            name = "Personal";
            url.file = config.sops.secrets.missiond_ics_personal.path;
            window = "12h";
            leads = ["5m" "0s"];
          };
        };
        calendarDefaults.poll = "5m";

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
