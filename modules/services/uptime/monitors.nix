{
  missionUptimeMonitors = [
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
    {
      name = "v3x-mediabus";
      group = "Local Homelab";
      url = "icmp://v3x-mediabus";
      interval = "1m";
      conditions = ["[CONNECTED] == true"];
    }
    {
      name = "v3x-alternator";
      group = "Local Homelab";
      url = "icmp://v3x-alternator";
      interval = "1m";
      conditions = ["[CONNECTED] == true"];
    }
    {
      name = "v3x-generator";
      group = "Local Homelab";
      url = "icmp://v3x-generator";
      interval = "1m";
      conditions = ["[CONNECTED] == true"];
    }
    {
      name = "v3x-watch";
      group = "Local Homelab";
      url = "icmp://v3x-watch";
      interval = "1m";
      conditions = ["[CONNECTED] == true"];
    }
    {
      name = "luc.computer";
      group = "Domains";
      url = "https://luc.computer";
      interval = "5m";
      conditions = [
        "[STATUS] < 400"
        "[CERTIFICATE_EXPIRATION] > 336h"
      ];
    }
    {
      name = "v3x.company";
      group = "Domains";
      url = "https://v3x.company";
      interval = "5m";
      conditions = [
        "[STATUS] < 400"
        "[CERTIFICATE_EXPIRATION] > 336h"
      ];
    }
    {
      name = "wallet.page";
      group = "Domains";
      url = "https://wallet.page";
      interval = "5m";
      conditions = [
        "[STATUS] < 400"
        "[CERTIFICATE_EXPIRATION] > 336h"
      ];
    }
    {
      name = "ethereum.forum";
      group = "Domains";
      url = "https://ethereum.forum";
      interval = "5m";
      conditions = [
        "[STATUS] < 400"
        "[CERTIFICATE_EXPIRATION] > 336h"
      ];
    }
    {
      name = "openlv.sh";
      group = "Domains";
      url = "https://openlv.sh";
      interval = "5m";
      conditions = [
        "[STATUS] < 400"
        "[CERTIFICATE_EXPIRATION] > 336h"
      ];
    }
    {
      name = "enstate.rs";
      group = "Domains";
      url = "https://enstate.rs";
      interval = "5m";
      conditions = [
        "[STATUS] < 400"
        "[CERTIFICATE_EXPIRATION] > 336h"
      ];
    }
  ];
}
