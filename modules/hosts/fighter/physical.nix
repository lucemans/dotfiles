{ self, ... }:
{
  flake.nixosModules.fighterPhysical = {
    imports = [
      self.nixosModules.fighterHardwareConfiguration
      self.nixosModules.fighterDisko
    ];

    boot.loader.systemd-boot.enable = true;
    # False while we develop this configuration, true when actually deploying
    boot.loader.efi.canTouchEfiVariables = false;
  };
}
