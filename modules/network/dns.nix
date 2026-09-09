_: let
  inherit (import ./topology.nix) hub zone resolver;
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

    services.dnsmasq = lib.mkIf isHub {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        bind-dynamic = true;
        listen-address = [resolver];
        local = "/${zone}/";
        host-record =
          lib.mapAttrsToList
          (addr: names: "${lib.concatStringsSep "," names},${addr}")
          allRecords;
      };
    };

    networking.firewall.extraCommands = lib.optionalString isHub ''
      iptables -A nixos-fw -i wg0 -d ${resolver} -p udp --dport 53 -j ACCEPT
    '';
  };
}
