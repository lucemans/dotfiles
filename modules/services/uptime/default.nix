{...}: let
  monitors = import ./monitors.nix;
in {
  flake.nixosModules.missionUptime = {...}: {
    services.gatus = {
      enable = true;
      openFirewall = false;
      settings = {
        metrics = true;
        web = {
          address = "127.0.0.1";
          port = 8080;
        };
        endpoints = monitors.missionUptimeMonitors;
      };
    };

    services.prometheus.exporters.snmp = {
      enable = true;
      listenAddress = "127.0.0.1";
      configuration = {
        auths.openviro = {
          community = "public";
          version = 1;
        };
        modules.rack_environment = {
          walk = [
            "1.3.6.1.2.1.99.1.1.1.4.0"
            "1.3.6.1.2.1.99.1.1.2.4.0"
            "1.3.6.1.2.1.99.1.2.1.4.0"
            "1.3.6.1.2.1.99.1.2.2.4.0"
          ];
          metrics = [
            {
              name = "rack_top_temperature_celsius";
              oid = "1.3.6.1.2.1.99.1.1.1.4.0";
              type = "gauge";
              help = "Server rack top temperature in Celsius.";
              scale = 0.01;
            }
            {
              name = "rack_top_humidity_percent";
              oid = "1.3.6.1.2.1.99.1.1.2.4.0";
              type = "gauge";
              help = "Server rack top relative humidity percentage.";
              scale = 0.001;
            }
            {
              name = "rack_bottom_temperature_celsius";
              oid = "1.3.6.1.2.1.99.1.2.1.4.0";
              type = "gauge";
              help = "Server rack bottom temperature in Celsius.";
              scale = 0.01;
            }
            {
              name = "rack_bottom_humidity_percent";
              oid = "1.3.6.1.2.1.99.1.2.2.4.0";
              type = "gauge";
              help = "Server rack bottom relative humidity percentage.";
              scale = 0.001;
            }
          ];
        };
      };
    };

    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      retentionTime = "30d";
      scrapeConfigs = [
        {
          job_name = "gatus";
          static_configs = [
            {
              targets = ["127.0.0.1:8080"];
            }
          ];
        }
        {
          job_name = "snmp-rack";
          metrics_path = "/snmp";
          params = {
            auth = ["openviro"];
            module = ["rack_environment"];
          };
          static_configs = [
            {
              targets = ["10.0.0.145"];
            }
          ];
          relabel_configs = [
            {
              source_labels = ["__address__"];
              target_label = "__param_target";
            }
            {
              source_labels = ["__param_target"];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9116";
            }
          ];
        }
      ];
    };
  };
}
