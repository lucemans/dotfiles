_: {
  flake.nixosModules.backup = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.v3x.backup;

    btrfs = lib.getExe' pkgs.btrfs-progs "btrfs";
    snapshotRoot = "/var/lib/restic-snapshots";
    snapshots = "v3x-backup-snapshots";

    isSubvolume = path: (config.fileSystems.${path}.fsType or null) == "btrfs";
    subvolumes = lib.filter isSubvolume cfg.paths;
    snapshotOf = path: "${snapshotRoot}/${lib.replaceStrings ["/"] ["-"] (lib.removePrefix "/" path)}";

    deleteSnapshots =
      lib.concatMapStringsSep "\n" (path: ''
        if [ -e ${snapshotOf path} ]; then
          ${btrfs} subvolume delete ${snapshotOf path}
        fi
      '')
      subvolumes;
  in {
    options.v3x.backup = {
      enable = lib.mkEnableOption "nightly restic backups";

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Directories to back up. Mount points of btrfs subvolumes are snapshotted first.";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Paths to leave out, as they appear on the running system.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "04:00";
        description = "systemd calendar expression for the nightly run.";
      };
    };

    config = lib.mkIf cfg.enable {
      sops.secrets = lib.genAttrs ["restic_repository" "restic_password" "restic_env"] (_: {});

      services.restic.backups.nightly = {
        repositoryFile = config.sops.secrets.restic_repository.path;
        passwordFile = config.sops.secrets.restic_password.path;
        environmentFile = config.sops.secrets.restic_env.path;
        initialize = true;

        inherit (cfg) paths exclude;

        timerConfig = {
          OnCalendar = cfg.schedule;
          RandomizedDelaySec = "15m";
          Persistent = true;
        };
        pruneOpts = [
          "--keep-daily 30"
          "--keep-monthly 3"
          "--group-by host"
        ];
        runCheck = true;
      };

      systemd.services = lib.mkIf (subvolumes != []) {
        restic-backups-nightly = {
          requires = ["${snapshots}.service"];
          after = ["${snapshots}.service"];
          serviceConfig.BindReadOnlyPaths = map (path: "${snapshotOf path}:${path}") subvolumes;
        };

        ${snapshots} = {
          description = "Read-only btrfs snapshots for the restic backup";
          unitConfig.StopWhenUnneeded = true;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -eu
            mkdir -p ${snapshotRoot}
            ${deleteSnapshots}
            ${lib.concatMapStringsSep "\n" (path: "${btrfs} subvolume snapshot -r ${path} ${snapshotOf path}") subvolumes}
          '';
          preStop = ''
            set -eu
            ${deleteSnapshots}
          '';
        };
      };
    };
  };
}
