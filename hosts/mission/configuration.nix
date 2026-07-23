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
    imports = [self.nixosModules.missionUptime];

    hardware.facter.reportPath = ./facter.json;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-mission";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";

    programs.niri.enable = true;

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
        };
        analytics.reporting_enabled = false;
        security.secret_key = "$__file{/var/lib/grafana/secret-key}";
        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Mission Prometheus";
              type = "prometheus";
              uid = "mission-prometheus";
              access = "proxy";
              url = "http://127.0.0.1:9090";
              isDefault = true;
            }
            {
              name = "Point Prometheus";
              type = "prometheus";
              uid = "point-prometheus";
              access = "proxy";
              url = "http://10.0.0.54:9090";
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "Mission";
              orgId = 1;
              folder = "Mission";
              type = "file";
              disableDeletion = false;
              editable = false;
              options.path = ./monitoring/dashboards;
            }
          ];
        };
      };
    };

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

    systemd.user.services.niri.enableDefaultPath = false;
    systemd.user.services.swaybg = {
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig.ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${self.wallpaper} -m fill";
    };

    systemd.user.services.mission-grafana-kiosk = {
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      serviceConfig = {
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl --fail --silent http://127.0.0.1:3000/api/health >/dev/null; do ${pkgs.coreutils}/bin/sleep 1; done'";
        ExecStart = "${pkgs.chromium}/bin/chromium --ozone-platform=wayland --kiosk --incognito --no-first-run --disable-session-crashed-bubble http://127.0.0.1:3000/d/mission-overview?orgId=1&kiosk";
        Restart = "always";
        RestartSec = 5;
      };
    };

    systemd.services.mission-display-off.serviceConfig = {
      Type = "oneshot";
      ExecStart = niriAction "power-off-monitors";
    };

    systemd.services.mission-display-on.serviceConfig = {
      Type = "oneshot";
      ExecStart = niriAction "power-on-monitors";
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
