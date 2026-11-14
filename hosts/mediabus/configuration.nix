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
      self.nixosModules.esphomeBuilder
      self.nixosModules.musicAssistant
      self.nixosModules.mediabusInference
      self.nixosModules.backup
      self.nixosModules.kettleForge
      self.nixosModules.kettleCode
      self.nixosModules.kettleRunner
    ];

    sops.defaultSopsFile = ../../config/mediabus.sops.yaml;
    v3x.backup = {
      enable = true;
      paths = [
        "/data"
        "/var/lib/immich"
        # "/var/lib/kettle-forge"
        # "/var/lib/kettle-code"
      ];
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-mediabus";
    networking.useDHCP = true;
    time.timeZone = "Europe/Amsterdam";

    zramSwap = {
      enable = true;
      memoryPercent = 100;
    };
    boot.kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.page-cluster" = 0;
    };

    services.kettle-runner.runCgroups = {
      enable = true;
      memoryHigh = 12 * 1024 * 1024 * 1024;
      memoryMax = 16 * 1024 * 1024 * 1024;
      pidsMax = 8192;
      cpuWeight = 50;
    };
    systemd.services.kettle-runner.serviceConfig = {
      MemoryMax = "70%";
      CPUWeight = 30;
      IOWeight = 30;
      OOMScoreAdjust = 500;
    };
    systemd.services.kettle-code.serviceConfig = {
      CPUWeight = 200;
      IOWeight = 200;
      OOMScoreAdjust = -900;
    };
    nix.daemonCPUSchedPolicy = "batch";
    nix.daemonIOSchedClass = "idle";

    nixpkgs.config.allowUnfree = true;
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

    users.groups.dockeruser.gid = 3000;
    users.users.dockeruser = {
      uid = 3000;
      group = "dockeruser";
      isSystemUser = true;
    };
    users.groups.storage.gid = 987;
    users.users.luc.extraGroups = ["docker" "dockeruser" "video"];

    systemd.tmpfiles.rules = [
      "d /data 0775 dockeruser root -"
    ];

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
