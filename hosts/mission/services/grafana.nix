{
  flake.nixosModules.missionGrafana = {pkgs, ...}: let
    missionDashboards = import ./dashboards {inherit pkgs;};
  in {
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

    systemd.user.services.mission-grafana-kiosk = {
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig = {
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl --fail --silent http://127.0.0.1:3000/api/playlists/mission-display >/dev/null; do ${pkgs.coreutils}/bin/sleep 1; done'";
        ExecStart = "${pkgs.chromium}/bin/chromium --ozone-platform=wayland --kiosk --incognito --no-first-run --disable-session-crashed-bubble http://127.0.0.1:3000/playlists/play/mission-display?kiosk&autofitpanels";
        Restart = "always";
        RestartSec = 5;
      };
    };

    systemd.services.mission-grafana-playlist = let
      playlist = builtins.toJSON {
        uid = "mission-display";
        name = "Mission Display";
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
          {
            type = "dashboard_by_uid";
            value = "indexer-prices";
          }
        ];
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
          playlist_url="$base_url/api/playlists/mission-display"
          response_file=/run/mission-grafana-playlist/response.json
          payload='${playlist}'

          until ${pkgs.curl}/bin/curl --fail --silent "$base_url/api/health" >/dev/null; do
            ${pkgs.coreutils}/bin/sleep 1
          done

          status="$(${pkgs.curl}/bin/curl --silent --output "$response_file" --write-out '%{http_code}' --user admin:admin "$playlist_url")"

          case "$status" in
            200)
              ${pkgs.curl}/bin/curl --fail --silent --show-error --request PUT --user admin:admin --header 'Content-Type: application/json' --data "$payload" "$playlist_url"
              ;;
            404)
              ${pkgs.curl}/bin/curl --fail --silent --show-error --request POST --user admin:admin --header 'Content-Type: application/json' --data "$payload" "$base_url/api/playlists"
              ;;
            *)
              ${pkgs.coreutils}/bin/cat "$response_file" >&2
              exit 1
              ;;
          esac
        '';
      };
    };
  };
}
