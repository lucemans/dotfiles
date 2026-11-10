let
  inherit (import ../../network/topology.nix) zone;
in {
  name = "mail.${zone}";
  relay = "v3x-pink";
  store = "v3x-watch";
  outboundPort = 10025;
  vmail = "/var/lib/vmail";
}
