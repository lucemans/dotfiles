_: {
  flake.nixosModules.patchPhysical = {
    config,
    lib,
    modulesPath,
    ...
  }: {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-amd"];
    boot.extraModulePackages = [];

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/78c4c988-824d-4236-a351-ca0bed0f2511";
      fsType = "ext4";
    };

    boot.initrd.luks.devices."luks-f0486431-2e72-4e22-9f9f-ba8e3d9579d5".device = "/dev/disk/by-uuid/f0486431-2e72-4e22-9f9f-ba8e3d9579d5";
    boot.initrd.luks.devices."luks-c8850dca-9dcf-4e50-aa4c-2920de3c23b2".device = "/dev/disk/by-uuid/c8850dca-9dcf-4e50-aa4c-2920de3c23b2";

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/41AA-0D2A";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };

    swapDevices = [];

    networking.useDHCP = lib.mkDefault true;

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
