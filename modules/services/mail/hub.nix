_: let
  inherit (import ../../network/hosts.nix) hosts;
  mail = import ./topology.nix;

  rule = "FORWARD -i wg0 -o wg0 -s ${hosts.${mail.relay}.address} -d ${hosts.${mail.store}.address} -p tcp --dport 25 -j ACCEPT";
in {
  flake.nixosModules.mailHub = _: {
    networking.firewall.extraCommands = ''
      iptables -I ${rule}
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D ${rule} 2>/dev/null || true
    '';
  };
}
