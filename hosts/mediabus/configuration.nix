_: {
  flake.nixosModules.mediabus = {
    self,
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.peripheral
      self.nixosModules.wireguard
      self.nixosModules.nodeMetrics
      self.nixosModules.dns
      self.nixosModules.immich
      self.nixosModules.mediabusInference
      self.nixosModules.backup
    ];

    sops.defaultSopsFile = ../../config/mediabus.sops.yaml;
    v3x.backup = {
      enable = true;
      # Both are btrfs subvolumes, so each is snapshotted before it is read.
      paths = ["/data" "/var/lib/immich"];
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-mediabus";
    networking.useDHCP = true;
    time.timeZone = "Europe/Amsterdam";

    zramSwap = {
      enable = true;
      memoryMax = 4 * 1024 * 1024 * 1024;
    };

    nixpkgs.config.allowUnfree = true;
    # Both RTX A4000 cards are Ampere, compute capability 8.6.
    nixpkgs.config.cudaCapabilities = ["8.6"];

    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    hardware.nvidia-container-toolkit.enable = true;

    virtualisation.docker.enable = true;

    systemd.services.nvidia-container-toolkit-cdi-generator = {
      requiredBy = lib.mkForce [];
      wantedBy = ["docker.service"];
      before = ["docker.service"];
    };

    # The NFS servers trust numeric ids (sec=sys), so these must match the ids that own the shares.
    users.groups.dockeruser.gid = 3000;
    users.users.dockeruser = {
      uid = 3000;
      group = "dockeruser";
      isSystemUser = true;
    };
    # Owns the NAS shares. The *arr containers run with this gid.
    users.groups.storage.gid = 987;
    users.users.luc.extraGroups = ["docker" "dockeruser" "video"];

    systemd.tmpfiles.rules = [
      "d /data 0775 dockeruser root -"
    ];

    # Mounted on first access, so a NAS that is down at boot does not block boot or fail the
    # containers that need it. A container that finds the share unreachable fails and restarts.
    fileSystems."/mnt/nas" = {
      device = "10.90.0.10:/";
      fsType = "nfs";
      options = ["vers=4.2" "_netdev" "soft" "timeo=5" "retrans=2" "x-systemd.automount" "x-systemd.mount-timeout=15"];
    };
    fileSystems."/mnt/generator" = {
      device = "10.90.0.12:/";
      fsType = "nfs";
      options = ["vers=4.2" "_netdev" "soft" "timeo=5" "retrans=2" "x-systemd.automount" "x-systemd.mount-timeout=15"];
    };

    environment.systemPackages = with pkgs; [
      btop
      htop
      vim
      net-tools
      rsync
      speedtest-cli
      llmfit
      sops
      age
    ];

    system.stateVersion = "26.05";
  };
}
