_: {
  flake.nixosModules.pink = {
    self,
    lib,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.peripheral
      self.nixosModules.wireguard
      self.nixosModules.mailRelay
    ];

    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    networking.hostName = "v3x-pink";
    networking.useDHCP = true;
    time.timeZone = "Europe/Amsterdam";
    networking.firewall.allowedTCPPorts = lib.mkForce [22 25];

    sops = {
      age.keyFile = "/var/lib/sops-nix/key.txt";
      age.sshKeyPaths = [];
      gnupg.sshKeyPaths = [];
      defaultSopsFile = ../../config/pink.sops.yaml;
    };

    environment.systemPackages = with pkgs; [
      sops
      age
    ];

    system.stateVersion = "26.05";
  };
}
