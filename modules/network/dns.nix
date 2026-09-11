_: let
  inherit (import ./topology.nix) hub resolver;
  inherit (import ./services.nix) services records;
  inherit (import ./hosts.nix) hosts;
in {
  flake.nixosModules.dns = {
    config,
    lib,
    ...
  }: let
    isHub = config.networking.hostName == hub;
    hubAddress = hosts.${hub}.address;

    allRecords =
      records
      // {
        ${hubAddress} =
          (records.${hubAddress} or [])
          ++ lib.mapAttrsToList (_: svc: svc.name) services;
      };
  in {
    networking.hosts = allRecords;

    networking.wireguard.interfaces.wg0.ips = lib.mkIf isHub ["${resolver}/32"];

    services.blocky = lib.mkIf isHub {
      enable = true;
      settings = {
        ports.dns = ["${resolver}:53"];
        upstreams.groups.default = [
          "tcp-tls:9.9.9.9:853#dns.quad9.net"
          "tcp-tls:1.1.1.1:853#one.one.one.one"
        ];
        customDNS.mapping = lib.listToAttrs (lib.concatMap
          (address:
            map (name: {
              inherit name;
              value = address;
            })
            allRecords.${address})
          (lib.attrNames allRecords));
        blocking = {
          denylists = {
            pro = ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt"];
            tif = ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/tif.txt"];
            multi = ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/multi.txt"];
          };
          clientGroupsBlock.default = ["pro" "tif" "multi"];
          loading = {
            strategy = "fast";
            refreshPeriod = "4h";
            downloads.cachePath = "/var/lib/blocky";
          };
        };
        caching = {
          minTime = "5m";
          prefetching = true;
        };
      };
    };

    systemd.services.blocky = lib.mkIf isHub {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };

    networking.firewall.extraCommands = lib.optionalString isHub ''
      iptables -A nixos-fw -i wg0 -d ${resolver} -p tcp --dport 53 -j ACCEPT
      iptables -A nixos-fw -i wg0 -d ${resolver} -p udp --dport 53 -j ACCEPT
    '';
  };
}
