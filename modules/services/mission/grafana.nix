let
  inherit (import ../../network/hosts.nix) hosts;
in {
  flake.nixosModules.missionGrafana = {
    config,
    pkgs,
    ...
  }: let
    missionDashboards = import ./dashboards {inherit pkgs;};
    meteredUsage = "http://${hosts.v3x-watch.address}:3000";
    infinity = pkgs.grafanaPlugins.yesoreyeram-infinity-datasource.overrideAttrs (old: {
      src = pkgs.fetchurl {
        inherit (old.src) name url;
        hash = "sha256-E3CBS3xVqdBJq4ylHaFmX75INZjI0fk6RX4yYNL1IhI=";
      };
    });
  in {
    sops.secrets.metered_usage_read_token = {
      owner = "grafana";
      mode = "0400";
      restartUnits = ["grafana.service"];
    };

    services.grafana = {
      enable = true;
      declarativePlugins = [
        pkgs.grafanaPlugins.prometheus
        infinity
      ];
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3001;
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
            {
              name = "Metered Usage";
              type = "yesoreyeram-infinity-datasource";
              uid = "metered-usage";
              url = "${meteredUsage}/api";
              jsonData = {
                auth_method = "bearerToken";
                allowedHosts = [meteredUsage];
              };
              secureJsonData.bearerToken = "$__file{${config.sops.secrets.metered_usage_read_token.path}}";
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
  };
}
