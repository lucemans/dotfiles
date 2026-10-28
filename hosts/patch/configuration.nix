{
  flake.nixosModules.patch = {
    self,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.workstation
      self.nixosModules.git
      self.nixosModules.wireguard
      self.nixosModules.dns
    ];

    system.stateVersion = "25.05";

    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    boot.kernelParams = ["amdgpu.abmlevel=0"];

    # The laptop boots with the scripted initrd on 25.05. nixpkgs unstable
    # enables the systemd initrd by default, which handles LUKS prompts and
    # absent devices differently.
    boot.initrd.systemd.enable = false;

    zramSwap.enable = true;

    networking.hostName = "v3x-patch";
    networking.networkmanager.enable = true;

    time.timeZone = "Europe/Amsterdam";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "nl_NL.UTF-8";
      LC_IDENTIFICATION = "nl_NL.UTF-8";
      LC_MEASUREMENT = "nl_NL.UTF-8";
      LC_MONETARY = "nl_NL.UTF-8";
      LC_NAME = "nl_NL.UTF-8";
      LC_NUMERIC = "nl_NL.UTF-8";
      LC_PAPER = "nl_NL.UTF-8";
      LC_TELEPHONE = "nl_NL.UTF-8";
      LC_TIME = "nl_NL.UTF-8";
    };

    services.xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    hardware.graphics.enable = true;

    temple = {
      activateLinux.monitors = ["eDP-1"];
      bar.monitors = {
        top = ["eDP-1"];
        bottom = ["eDP-1"];
      };
    };

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    services.printing.enable = true;

    services.avahi = {
      enable = true;
      nssmdns4 = true;
    };

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.Enable = "Source,Sink,Media,Socket";
    };
    services.blueman.enable = true;

    services.fprintd.enable = true;
    security.pam.services = {
      login.fprintAuth = true;
      sudo.fprintAuth = true;
      polkit-1.fprintAuth = true;
      bitwarden.fprintAuth = true;
    };

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

    hardware.rtl-sdr.enable = true;
    services.udev.packages = [pkgs.rtl-sdr];
    users.groups.plugdev = {};
    # rtl-sdr cannot claim the device while the kernel DVB drivers hold it.
    boot.blacklistedKernelModules = ["dvb_usb_rtl28xxu" "rtl2832" "rtl2832_sdr"];

    services.tailscale.enable = true;
    services.mullvad-vpn.enable = true;

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
          "v3x-fighter" = {
            id = "OCMZU36-ONHXLBB-GBH7GVO-MTVB5D6-SVYS7LH-PO2K2WU-HQ37SD6-CFCPLQG";
          };
        };
        folders = {
          "vault" = {
            path = "/home/luc/sync/vault";
            devices = ["v3x-fighter"];
          };
        };
      };
    };

    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
    };

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    programs.fish.enable = true;

    home-manager.backupFileExtension = "backup";
    home-manager.users.luc = {
      programs.plasma.enable = false;
      programs.firefox.configPath = ".mozilla/firefox";
    };

    users.users.luc = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
        "plugdev"
        "fprintd"
      ];
      packages = with pkgs; [
        kubectl
        eza
        libusb1
        cifs-utils
        samba
        mullvad-vpn
        syncthing

        vscode
        code-cursor
        spotify
        gitkraken
        opencode

        rtl-sdr

        rustup
        bacon
        gcc
        openssl
        openssl.dev
        pkg-config
        rustc

        nodejs
        pnpm

        jetbrains.datagrip
        exiftool
        ferium
        codex
      ];
    };

    environment.systemPackages = with pkgs; [
      vim
      wget
      git
      micro
      firefox-devedition
      gnumake
      lm_sensors
      stress-ng
    ];
  };
}
