{lib, ...}: let
  inherit (import ../network/services.nix) services;

  port = 6055;
  stateDir = "/var/lib/esphome-builder";
  dashboard = builtins.head (lib.splitString ":" services.home.upstream);
in {
  flake.nixosModules.esphomeBuilder = {
    config,
    pkgs,
    ...
  }: {
    assertions = [
      {
        assertion = config.programs.nix-ld.enable;
        message = "esphomeBuilder needs programs.nix-ld: PlatformIO toolchains are prebuilt binaries.";
      }
    ];

    users.users.esphome-builder = {
      isSystemUser = true;
      group = "esphome-builder";
      home = stateDir;
    };
    users.groups.esphome-builder = {};

    systemd.services.esphome-build-server = {
      description = "ESPHome build server";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.git pkgs.gnupatch];

      environment = {
        HOME = stateDir;
        PLATFORMIO_CORE_DIR = "${stateDir}/.platformio";
      };

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.esphome-device-builder)
          "--remote-build-only"
          "--remote-build-port ${toString port}"
          "--allow-pairing-source ${dashboard}"
          stateDir
        ];
        User = "esphome-builder";
        Group = "esphome-builder";
        WorkingDirectory = stateDir;
        StateDirectory = "esphome-builder";
        StateDirectoryMode = "0750";
        Restart = "on-failure";

        CPUWeight = 10;
        MemoryHigh = "8G";
        MemoryMax = "12G";

        CapabilityBoundingSet = "";
        DevicePolicy = "closed";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelModules = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_NETLINK" "AF_UNIX"];
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };

    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -s ${dashboard} -p tcp --dport ${toString port} -j ACCEPT
    '';
  };
}
