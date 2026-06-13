{
  flake.nixosModules.fighter = {
    self,
    pkgs,
    lib,
    config,
    ...
  }: {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
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
    services.pulseaudio.enable = false;
    # services.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    services.printing.enable = true;

    services.tailscale = {
      enable = true;
    };
    services.nix-ld.enable = true;

    users.users.luc = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      packages = with pkgs; [];
    };

    environment.systemPackages = with pkgs; [
      vim
      wget
      micro
      curl
      git
      pciutils
      usbutils
    ];

    # services.fstrim.enable = true;

    system.stateVersion = "26.05";
  };
}
