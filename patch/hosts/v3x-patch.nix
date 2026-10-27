{ config, pkgs, ... }:

{
  networking.hostName = "v3x-patch";  # Define the machine's hostname

  # Add kernel parameters for AMD GPU
  boot.kernelParams = [ "amdgpu.abmlevel=0" ];

  # Prevent keyboard from waking the system when lid is closed
  services.udev.extraRules = ''
    # Framework Laptop 16 Keyboard Module - ANSI
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0012", ATTR{power/wakeup}="disabled"

    # Framework Laptop 16 RGB Macropad
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0013", ATTR{power/wakeup}="disabled"

    # Framework Laptop 16 Numpad Module
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0014", ATTR{power/wakeup}="disabled"

    # Framework Laptop 16 Keyboard Module - ISO
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0018", ATTR{power/wakeup}="disabled"
  '';

  imports = [
    ./common.nix
    ../modules/system-packages.nix
  ];

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable graphical environment (Plasma)
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Enable sound (PipeWire)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    # Streaming
    # rtp.enable = true;
    # DLNA/RAOP
    # raop.enable = true;
  };

  # Enable fingerprint support
  services.fprintd.enable = true;

  # Configure PAM for fingerprint authentication
  security.pam.services = {
    login.fprintAuth = true;
    sudo.fprintAuth = true;
    polkit-1.fprintAuth = true;
    bitwarden.fprintAuth = true;
  };

  # Define user account
  users.users.luc = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "fprintd" "plugdev" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable Bluetooth support
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;  # Automatically power on Bluetooth adapter at boot
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };

  hardware.rtl-sdr.enable = true;

  # Enable Bluetooth service
  services.blueman.enable = true;  # Provides a graphical Bluetooth manager

  # Enable Tailscale
  services.tailscale = {
    enable = true;
    # autoconnect = {
      # enable = true;
      # Optionally add authkey if you want automatic authentication
      # authKeyFile = "/path/to/tailscale/authkey";
    # };
  };

  services.syncthing = {
    enable = true;
    group = "users";
    user = "luc";
    dataDir = "/home/luc/sync";
    configDir = "/home/luc/sync/.config/syncthing";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "v3x-fighter" = { id = "OCMZU36-ONHXLBB-GBH7GVO-MTVB5D6-SVYS7LH-PO2K2WU-HQ37SD6-CFCPLQG"; };
      };
      folders = {
        "vault" = {
          path = "/home/luc/sync/vault";
          devices = [ "v3x-fighter" ];
        };
      };
    };
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };
}
