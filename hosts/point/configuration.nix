{
  config,
  lib,
  pkgs,
  ethereum-nix,
  ...
}: {
  flake.nixosModules.point = {
    self,
    pkgs,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules.peripheral
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-point";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";

    networking.firewall.allowedTCPPorts = [
      30303
      9200
      8545
      3000
      9090
    ];
    networking.firewall.allowedUDPPorts = [
      30303
      9200
      8545
    ];
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -p tcp -s 10.90.0.60 --dport 9090 -j ACCEPT
    '';

    system.stateVersion = "26.05";
  };
}
