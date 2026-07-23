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
    hardware.facter.reportPath = ./facter.json;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-mission";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";

    programs.niri.enable = true;

    services.greetd = {
      enable = true;
      settings.initial_session = {
        command = "${config.programs.niri.package}/bin/niri-session";
        user = "luc";
      };
      settings.default_session = {
        command = "${config.programs.niri.package}/bin/niri-session";
        user = "luc";
      };
    };

    # Let niri-session provide the session PATH to Niri and its user services.
    systemd.user.services.niri.enableDefaultPath = false;
    systemd.user.services.swaybg = {
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig.ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${self.wallpaper} -m fill";
    };

    systemd.services.mission-display-off = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = niriAction "power-off-monitors";
      };
    };

    systemd.services.mission-display-on = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = niriAction "power-on-monitors";
      };
    };

    environment.systemPackages = [pkgs.kitty.terminfo];

    users.users.luc = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      openssh.authorizedKeys.keyFiles = [
        ../../secrets/ssh.key
      ];
      packages = with pkgs; [
        tree
        micro
        git
        lnav
        jq
        tmux
      ];
    };

    security.sudo.wheelNeedsPassword = false;
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [
      22
      2022
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

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    services.fstrim.enable = true;

    system.stateVersion = "26.05";
  };
}
