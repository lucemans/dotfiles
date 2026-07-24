{
  config,
  lib,
  pkgs,
  ...
}: {
  flake.nixosModules.mission = {
    self,
    config,
    pkgs,
    lib,
    ...
  }: let
    missionNiriConfig =
      pkgs.runCommand "mission-niri-config.kdl" {
        nativeBuildInputs = [config.programs.niri.package];
      } ''
          install -Dm644 ${config.programs.niri.package.src}/resources/default-config.kdl $out
          printf '\ncursor {\n    hide-after-inactive-ms 60000\n}\n' >> $out
        niri validate --config $out
      '';
    missionNiriSession = pkgs.writeShellScript "mission-niri-session" ''
      export NIRI_CONFIG=/etc/niri/config.kdl
      exec ${config.programs.niri.package}/bin/niri-session
    '';
    niriAction = action:
      pkgs.writeShellScript "mission-${action}" ''
        for niriSocket in /run/user/1000/niri.*.sock; do
          if [ ! -S "$niriSocket" ]; then
            continue
          fi

          if ${pkgs.util-linux}/bin/runuser -u luc -- ${pkgs.coreutils}/bin/env NIRI_SOCKET="$niriSocket" ${config.programs.niri.package}/bin/niri msg action ${action}; then
            exit 0
          fi
        done

        exit 1
      '';
  in {
    imports = [
      self.nixosModules.peripheral
      self.nixosModules.missionUptime
      self.nixosModules.missionGrafana
    ];

    hardware.facter.reportPath = ./facter.json;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-mission";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";

    programs.niri.enable = true;
    environment.etc."niri/config.kdl".source = missionNiriConfig;

    services.greetd = {
      enable = true;
      settings.initial_session = {
        command = missionNiriSession;
        user = "luc";
      };
      settings.default_session = {
        command = missionNiriSession;
        user = "luc";
      };
    };

    systemd.user.services.niri.enableDefaultPath = false;
    systemd.user.services.swaybg = {
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig.ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${self.wallpaper} -m fill";
    };

    systemd.services.mission-display-off.serviceConfig = {
      Type = "oneshot";
      ExecStart = niriAction "power-off-monitors";
    };

    systemd.services.mission-display-on.serviceConfig = {
      Type = "oneshot";
      ExecStart = niriAction "power-on-monitors";
    };

    networking.firewall.allowedTCPPorts = [
      30303
      9200
      8545
      3000
    ];
    networking.firewall.allowedUDPPorts = [
      30303
      9200
      8545
    ];

    environment.systemPackages = [pkgs.kitty.terminfo];

    system.stateVersion = "26.05";
  };
}
