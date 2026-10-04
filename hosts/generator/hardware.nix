_: {
  flake.nixosModules.generatorPhysical = {
    config,
    lib,
    ...
  }: {
    boot.initrd.availableKernelModules = [
      "nvme"
      "ahci"
      "xhci_pci"
      "usbhid"
      "sd_mod"
    ];

    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.extraModulePackages = [];

    hardware.cpu.intel.updateMicrocode =
      lib.mkDefault true;
  };
}
