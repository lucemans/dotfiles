{
  config,
  lib,
  pkgs,
  ethereum-nix,
  ...
}:
{
  flake.nixosModules.fighter =
    {
      self,
      pkgs,
      lib,
      config,
      ...
    }:
    {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      networking.hostName = "v3x-fighter";
      networking.networkmanager.enable = true;
      time.timeZone = "Europe/Amsterdam";

      services.displayManager.sddm.enable = true;
      services.desktopManager.plasma6.enable = true;
      nixpkgs.config.allowUnfree = true;
      services.xserver = {
      	enable = true;
      	videoDrivers = [ "nvidia" ];
      };
      hardware.graphics.enable = true;
      hardware.nvidia = {
      	modesetting.enable = true;
      	powerManagement.enable = false;
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

      users.users.luc = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        packages = with pkgs; [
          tree
          firefox
          fastfetch
          zed-editor
          gitkraken
          signal-desktop
          opencode
        ];
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.luc = import ./home.nix;
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

      nix.settings.experimental-features = [ "nix-command" "flakes" ];

      # services.fstrim.enable = true;

      system.stateVersion = "26.05";
    };
}
