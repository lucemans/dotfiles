{...}: let
  inherit (import ./topology.nix) hub hubPort subnet trusted guests resolver hosts;
in {
  flake.nixosModules.wireguard = {
    config,
    lib,
    ...
  }: let
    me = hosts.${config.networking.hostName};
    isHub = config.networking.hostName == hub;
  in {
    options.v3x.address = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = me.address;
      description = "This host's address on the v3x tunnel.";
    };

    config = {
      networking.wireguard.interfaces.wg0 = {
        ips = ["${me.address}/32"];

        privateKeyFile = "/var/lib/wireguard/wg0.key";
        generatePrivateKeyFile = true;

        listenPort = lib.mkIf isHub hubPort;
        peers =
          if isHub
          then
            lib.mapAttrsToList (name: host: {
              inherit name;
              inherit (host) publicKey;
              allowedIPs = ["${host.address}/32"];
            }) (lib.filterAttrs (name: _: name != hub) hosts)
          else [
            {
              name = hub;
              inherit (hosts.${hub}) publicKey endpoint;
              allowedIPs = [subnet];
              persistentKeepalive = 25;
            }
          ];
      };

      networking.firewall.allowedUDPPorts = lib.mkIf isHub [hubPort];
      networking.firewall.extraCommands =
        ''
          iptables -A nixos-fw -i wg0 -s ${trusted} -j ACCEPT
          iptables -A nixos-fw -i wg0 -p icmp --icmp-type echo-request -j ACCEPT
        ''
        + lib.optionalString isHub ''
          iptables -A FORWARD -i wg0 -s ${guests} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
          iptables -A FORWARD -i wg0 -s ${guests} -j DROP

          # v3x-guest-allow is populated by other modules, so it is created
          # here but never flushed here.
          iptables -N v3x-guest-allow 2>/dev/null || true

          iptables -N v3x-guests 2>/dev/null || iptables -F v3x-guests
          iptables -A v3x-guests -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
          iptables -A v3x-guests -p icmp --icmp-type echo-request -j ACCEPT
          iptables -A v3x-guests -d ${resolver} -p udp --dport 53 -j ACCEPT
          iptables -A v3x-guests -j v3x-guest-allow
          iptables -A v3x-guests -j DROP
          iptables -I nixos-fw 1 -i wg0 -s ${guests} -j v3x-guests
        ''
        + lib.optionalString (!isHub) ''
          # applications that bind to the default route address (sofia-sip) would
          # otherwise be dropped by the hub, which allows this peer's address only.
          iptables -t nat -A POSTROUTING -o wg0 ! -s ${me.address} -j SNAT --to-source ${me.address}
        '';

      networking.firewall.extraStopCommands =
        ''
          iptables -D nixos-fw -i wg0 -s ${trusted} -j ACCEPT 2>/dev/null || true
          iptables -D nixos-fw -i wg0 -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null || true
        ''
        + lib.optionalString isHub ''
          iptables -D FORWARD -i wg0 -s ${guests} -j DROP 2>/dev/null || true
          iptables -D FORWARD -i wg0 -s ${guests} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

          iptables -D nixos-fw -i wg0 -s ${guests} -j v3x-guests 2>/dev/null || true
          iptables -F v3x-guests 2>/dev/null || true
          iptables -X v3x-guests 2>/dev/null || true
          iptables -F v3x-guest-allow 2>/dev/null || true
          iptables -X v3x-guest-allow 2>/dev/null || true
        ''
        + lib.optionalString (!isHub) ''
          iptables -t nat -D POSTROUTING -o wg0 ! -s ${me.address} -j SNAT --to-source ${me.address} 2>/dev/null || true
        '';

      boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkIf isHub 1;
    };
  };
}
