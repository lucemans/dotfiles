{
  config,
  lib,
  pkgs,
  ethereum-nix,
  ...
}: {
  flake.nixosModules.teapot = {
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
    networking.hostName = "v3x-teapot";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";

    networking.firewall.allowedTCPPorts = [
    ];
    networking.firewall.allowedUDPPorts = [
    ];

    system.stateVersion = "26.05";
  };
}
