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

    services.avahi = {
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
        "video"
        "plugdev"
      ];
      packages = with pkgs; [];
    };

    users.groups.plugdev = {};

    services.udev.extraRules = ''
      # Xbox Kinect / Kinect for Xbox 360
      SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02ae", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02ad", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02b0", MODE="0660", GROUP="plugdev", TAG+="uaccess"

      # Sometimes useful for libfreenect / USB device nodes
      SUBSYSTEM=="usb_device", ATTR{idVendor}=="045e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    '';

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

    networking = {
      firewall = {
        enable = true;
        allowedUDPPortRanges = [
          {
            from = 60000;
            to = 60010;
          }
          {
            from = 1714;
            to = 1764;
          }
        ];
        allowedTCPPortRanges = [
          {
            from = 60000;
            to = 60010;
          }
          {
            from = 1714;
            to = 1764;
          }
        ];
      };

      hosts = {
        "127.0.0.2" = ["firefly.internal"];
        "127.0.0.3" = ["firefly-data.internal"];
      };
    };

    # services.fstrim.enable = true;
    # services.angrr = {
    #   enable = true;
    #   period = "7d";
    # };

    nix.gc.automatic = true;

    nixpkgs.config.allowUnfree = true;

    nixpkgs.overlays = [
      (final: prev: {
        # patool 4.0.5's archive tests fail under Python 3.14 in the Nix sandbox.
        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (pythonPackages: super: {
              patool = super.patool.overridePythonAttrs (old: {
                doCheck = false;
              });
            })
          ];
      })
    ];

    system.stateVersion = "26.05";
  };
}
