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
      ];
    };
  };
}
