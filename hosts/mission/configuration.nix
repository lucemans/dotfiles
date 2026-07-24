{
  config,
  lib,
  pkgs,
  ...
}: {
  flake.nixosModules.mission = {
    self,
    config,
    pkgs,
    lib,
    ...
  }: let
    homelabDashboard = pkgs.writeTextDir "homelab.json" (builtins.toJSON (import ./monitoring/homelab-dashboard.nix));
    missionDashboards = pkgs.symlinkJoin {
      name = "mission-dashboards";
      paths = [
        ./monitoring/dashboards
        homelabDashboard
      ];
    };
    missionNiriConfig =
      pkgs.runCommand "mission-niri-config.kdl" {
        nativeBuildInputs = [config.programs.niri.package];
      } ''
          install -Dm644 ${config.programs.niri.package.src}/resources/default-config.kdl $out
          printf '\ncursor {\n    hide-after-inactive-ms 60000\n}\n' >> $out
        niri validate --config $out
      '';
    missionNiriSession = pkgs.writeShellScript "mission-niri-session" ''
      export NIRI_CONFIG=/etc/niri/config.kdl
      exec ${config.programs.niri.package}/bin/niri-session
    '';
    niriAction = action:
      pkgs.writeShellScript "mission-${action}" ''
        for niriSocket in /run/user/1000/niri.*.sock; do
          if [ ! -S "$niriSocket" ]; then
            continue
          fi

          if ${pkgs.util-linux}/bin/runuser -u luc -- ${pkgs.coreutils}/bin/env NIRI_SOCKET="$niriSocket" ${config.programs.niri.package}/bin/niri msg action ${action}; then
            exit 0
          fi
        done

        exit 1
      '';
  in {
    imports = [
      self.nixosModules.peripheral
      self.nixosModules.missionUptime
    ];

    hardware.facter.reportPath = ./facter.json;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-mission";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";

    programs.niri.enable = true;
    environment.etc."niri/config.kdl".source = missionNiriConfig;

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
        };
        analytics.reporting_enabled = false;
        security.secret_key = "$__file{/var/lib/grafana/secret-key}";
        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Mission Prometheus";
              type = "prometheus";
              uid = "mission-prometheus";
              access = "proxy";
              url = "http://127.0.0.1:9090";
              isDefault = true;
            }
            {
              name = "Point Prometheus";
              type = "prometheus";
              uid = "point-prometheus";
              access = "proxy";
              url = "http://10.0.0.54:9090";
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "Mission";
              orgId = 1;
              folder = "Mission";
              type = "file";
              disableDeletion = false;
              editable = false;
              options.path = missionDashboards;
            }
          ];
        };
      };
    };

    systemd.services.mission-grafana-playlist = let
      playlist = builtins.toJSON {
        apiVersion = "playlist.grafana.app/v1";
        kind = "Playlist";
        metadata.name = "mission-display";
        spec = {
          title = "Mission Display";
          interval = "1m";
          items = [
            {
              type = "dashboard_by_uid";
              value = "mission-overview";
            }
            {
              type = "dashboard_by_uid";
              value = "homelab-uptime";
            }
          ];
        };
      };
    in {
      description = "Provision the Mission Grafana display playlist";
      wantedBy = ["multi-user.target"];
      requires = ["grafana.service"];
      after = ["grafana.service"];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "mission-grafana-playlist";
        ExecStart = pkgs.writeShellScript "mission-grafana-playlist" ''
          set -euo pipefail

          base_url=http://127.0.0.1:3000
          playlist_url="$base_url/apis/playlist.grafana.app/v1/namespaces/default/playlists/mission-display"
          response_file=/run/mission-grafana-playlist/response.json
          payload='${playlist}'

          until ${pkgs.curl}/bin/curl --fail --silent "$base_url/api/health" >/dev/null; do
            ${pkgs.coreutils}/bin/sleep 1
          done

          status="$(${pkgs.curl}/bin/curl --silent --output "$response_file" --write-out '%{http_code}' --request DELETE --user admin:admin "$playlist_url")"

          case "$status" in
            200 | 404)
              ${pkgs.curl}/bin/curl --fail --silent --show-error --request POST --user admin:admin --header 'Content-Type: application/json' --data "$payload" "$playlist_url"
              ;;
            *)
              ${pkgs.coreutils}/bin/cat "$response_file" >&2
              exit 1
              ;;
          esac
        '';
      };
    };

    services.greetd = {
      enable = true;
      settings.initial_session = {
        command = missionNiriSession;
        user = "luc";
      };
      settings.default_session = {
        command = missionNiriSession;
        user = "luc";
      };
    };

    systemd.user.services.niri.enableDefaultPath = false;
    systemd.user.services.swaybg = {
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig.ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${self.wallpaper} -m fill";
    };

    systemd.user.services.mission-grafana-kiosk = {
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig = {
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl --fail --silent http://127.0.0.1:3000/apis/playlist.grafana.app/v1/namespaces/default/playlists/mission-display >/dev/null; do ${pkgs.coreutils}/bin/sleep 1; done'";
        ExecStart = "${pkgs.chromium}/bin/chromium --ozone-platform=wayland --kiosk --incognito --no-first-run --disable-session-crashed-bubble http://127.0.0.1:3000/playlists/play/mission-display?kiosk&autofitpanels";
        Restart = "always";
        RestartSec = 5;
      };
    };

    systemd.services.mission-display-off.serviceConfig = {
      Type = "oneshot";
      ExecStart = niriAction "power-off-monitors";
    };

    systemd.services.mission-display-on.serviceConfig = {
      Type = "oneshot";
      ExecStart = niriAction "power-on-monitors";
    };

    networking.firewall.allowedTCPPorts = [
      30303
      9200
      8545
      3000
    ];
    networking.firewall.allowedUDPPorts = [
      30303
      9200
      8545
    ];

    environment.systemPackages = [pkgs.kitty.terminfo];

    system.stateVersion = "26.05";
  };
}
