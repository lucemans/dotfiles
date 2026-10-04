_: {
  flake.nixosModules.generator = {self, ...}: {
    imports = [
      self.nixosModules.peripheral
      self.nixosModules.wireguard
      self.nixosModules.nodeMetrics
      self.nixosModules.dns
      self.nixosModules.generatorPhysical
    ];

    networking.hostName = "v3x-generator";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.useNetworkd = true;

    networking.bonds.bond0 = {
      interfaces = ["enp1s0" "enp2s0"];
      driverOptions = {
        mode = "802.3ad";
        miimon = "1000";
        xmit_hash_policy = "layer3+4";
        lacp_rate = "fast";
      };
    };

    systemd.network.networks."30-bond0" = {
      matchConfig.Name = "bond0";
      address = ["10.90.0.12/24"];
      routes = [
        {Gateway = "10.90.0.1";}
      ];
      networkConfig.DNS = ["10.90.0.10"];
    };

    users.groups.storage.gid = 987;

    users.users.luc = {
      uid = 1000;
      extraGroups = ["storage"];
    };

    fileSystems."/mnt/diska" = {
      device = "/dev/disk/by-uuid/c242c170-8a22-4f35-977a-b458e1c47ed0";
      fsType = "ext4";
    };

    fileSystems."/mnt/diskb" = {
      device = "/dev/disk/by-uuid/c81554a4-fb87-4a8c-8f25-67141a4610a6";
      fsType = "ext4";
    };

    fileSystems."/mnt/diskc" = {
      device = "/dev/disk/by-uuid/a80e5caa-cb9e-4388-800b-33c0a9a70d70";
      fsType = "ext4";
    };

    fileSystems."/mnt/diskd" = {
      device = "/dev/disk/by-uuid/917c6d64-6bfc-4969-866f-200199011e76";
      fsType = "ext4";
    };

    system.stateVersion = "26.05";
  };
}
