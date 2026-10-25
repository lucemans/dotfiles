_: {
  flake.nixosModules.mediabusDisko = {lib, ...}: {
    disko.devices = {
      disk.main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = ["compress=zstd:3" "noatime"];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd:3" "noatime"];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = ["compress=zstd:3" "noatime"];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = ["compress=zstd:3" "noatime"];
                  };
                  "@data" = {
                    mountpoint = "/data";
                    mountOptions = ["compress=zstd:3" "noatime"];
                  };
                  "@immich" = {
                    mountpoint = "/var/lib/immich";
                    mountOptions = ["compress=zstd:3" "noatime"];
                  };
                  "@models" = {
                    mountpoint = "/var/lib/llama-models";
                    mountOptions = ["noatime"];
                  };
                };
              };
            };
          };
        };
      };
    };

    disko.tests.extraConfig = {
      services.immich.enable = lib.mkForce false;
      services.llama-swap.enable = lib.mkForce false;
      systemd.services.llama-models-fetch.enable = lib.mkForce false;
    };

    disko.tests.extraChecks = ''
      machine.wait_for_unit("docker.service")
      machine.succeed("docker info")
    '';
  };
}
