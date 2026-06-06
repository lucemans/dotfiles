{ ... }:
{
  flake.nixosModules.fighterVm =
    { lib, modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/virtualisation/qemu-vm.nix")
      ];

      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.initrd.systemd.enable = true;

      # qemu-vm replaces fileSystems with virtualisation.fileSystems — define mounts there.
      virtualisation = {
        diskImage = lib.mkForce null;

        emptyDiskImages = [
          { size = 1024; }
        ];

        # Only virtio-blk disk when diskImage is null; label does not exist until
        # autoFormat runs in stage 2 — do not wait for it in initrd (90s hang).
        fileSystems."/persistent" = {
          device = "/dev/vda";
          fsType = "ext4";
          autoFormat = true;
          neededForBoot = false;
        };

        memorySize = 8192;
        cores = 4;
        qemu.options = [
          "-device"
          "qxl-vga,vgamem_mb=32"
          "-display"
          "gtk,show-cursor=on"
        ];
      };

      networking.hostName = lib.mkDefault "v3x-fighter-vm";

      users.users.luc.extraGroups = lib.mkAfter [
        "video"
        "render"
        "input"
      ];
    };
}
