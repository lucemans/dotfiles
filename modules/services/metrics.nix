_: {
  flake.nixosModules.nodeMetrics = {pkgs, ...}: let
    textfileDir = "/var/lib/node-exporter-textfile";
    nixStoreMetrics = pkgs.writeShellScript "nix-store-metrics" ''
      set -euo pipefail

      bytes=$(${pkgs.coreutils}/bin/du -sB1 /nix/store | ${pkgs.coreutils}/bin/cut -f1)
      tmp=${textfileDir}/.nix-store.prom.$$
      printf 'nix_store_size_bytes %s\n' "$bytes" > "$tmp"
      mv "$tmp" ${textfileDir}/nix-store.prom
    '';
  in {
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = 9100;
      enabledCollectors = ["textfile"];
      extraFlags = ["--collector.textfile.directory=${textfileDir}"];
    };

    services.prometheus.exporters.smartctl = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = 9633;
    };

    networking.firewall.interfaces.wg0.allowedTCPPorts = [9100 9633];

    systemd.tmpfiles.rules = ["d ${textfileDir} 0755 root root -"];

    systemd.services.nix-store-metrics = {
      description = "Write /nix/store size to the node exporter textfile directory";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = nixStoreMetrics;
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.nix-store-metrics = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        OnBootSec = "15min";
        Persistent = true;
      };
    };
  };
}
