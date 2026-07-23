{...}: {
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
        endpoints = [
          {
            name = "Prometheus";
            group = "Ethereum";
            url = "http://10.0.0.54:9090/-/healthy";
            interval = "1m";
            conditions = ["[STATUS] == 200"];
          }
          {
            name = "RPC";
            group = "Ethereum";
            url = "tcp://10.0.0.54:8545";
            interval = "1m";
            conditions = ["[CONNECTED] == true"];
          }
          {
            name = "Beacon";
            group = "Ethereum";
            url = "http://10.0.0.54:5052/eth/v1/node/health";
            interval = "1m";
            conditions = ["[STATUS] < 300"];
          }
        ];
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
