{
  flake.nixosModules.fighter = {
    self,
    pkgs,
    lib,
    config,
    ...
  }: {
    boot.loader = {
      efi.canTouchEfiVariables = true;
    };
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    networking.hostName = "v3x-fighter";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";

    services.xserver = {
      enable = true;
      videoDrivers = ["nvidia"];
      xkb = {
        layout = "us";
        options = "caps:super";
      };
    };
    hardware.graphics.enable = true;
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
    hardware.enableRedistributableFirmware = true;
    services.printing.enable = true;

    services.tailscale = {
      enable = true;
    };

    programs.calls.enable = true;
    services.gnome.evolution-data-server.enable = true;

    services.pcscd = {
      enable = true;
    };

    virtualisation.docker = {
      enable = true;
      storageDriver = "btrfs";
    };

    users.users.luc = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "uucp"
        "docker"
      ];
      packages = with pkgs; [
      ];
    };

    environment.systemPackages = with pkgs; [
      vim
      wget
      micro
      curl
      git
      pciutils
      usbutils
      hackrf
      pcsclite
      pcsc-tools
      yubikey-manager
      openssl
      net-tools
    ];

    networking.hosts = {
      "127.0.0.2" = ["firefly.internal"];
      "127.0.0.3" = ["firefly-data.internal"];
    };

    # services.fstrim.enable = true;

    system.stateVersion = "26.05";
  };
}
