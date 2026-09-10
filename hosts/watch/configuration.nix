_: {
  flake.nixosModules.watch = {
    self,
    lib,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.peripheral
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.initrd.systemd.enable = true;
    boot.initrd.availableKernelModules = ["igc"];
    boot.initrd.network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        hostKeys = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
        authorizedKeyFiles = [../../secrets/ssh2.key];
      };
    };

    disko.tests = {
      enableOCR = true;
      bootCommands = ''
        machine.wait_for_text("[Pp]assphrase for")
        machine.send_chars("secretsecret\n")
      '';
      extraConfig = {
        boot.initrd.network.ssh.hostKeys = lib.mkForce [
          (pkgs.runCommand "initrd-test-host-key" {nativeBuildInputs = [pkgs.openssh];} ''
            ssh-keygen -t ed25519 -N "" -f key
            mv key $out
          '')
        ];
      };
    };

    boot.kernelParams = ["ip=dhcp"];

    boot.blacklistedKernelModules = ["iwlwifi"];

    # preservation reads /persist before stage 2, so disko's mount is not early enough on its own.
    fileSystems."/persist".neededForBoot = true;

    preservation = {
      enable = true;
      preserveAt."/persist" = {
        files = [
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
        ];
        directories = [
          "/etc/secrets"
          "/var/lib/docker"
          "/var/lib/nixos"
          "/var/lib/sbctl"
          "/var/lib/systemd"
          "/var/lib/wireguard"
          "/var/log"
        ];
      };
    };

    systemd.suppressedSystemUnits = ["systemd-machine-id-commit.service"];

    services.openssh.hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];

    virtualisation.docker.enable = true;

    networking.hostName = "v3x-watch";
    networking.useDHCP = true;
    time.timeZone = "Europe/Amsterdam";

    system.stateVersion = "26.05";
  };
}
