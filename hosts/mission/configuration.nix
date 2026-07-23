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
    uptimeTargets = [
      {
        id = "point-prometheus";
        label = "v3x-point Prometheus";
        module = "http_2xx";
        target = "http://10.0.0.54:9090/-/healthy";
      }
      {
        id = "point-rpc";
        label = "v3x-point RPC";
        module = "tcp_connect";
        target = "10.0.0.54:8545";
      }
      {
        id = "point-beacon";
        label = "v3x-point Beacon";
        module = "http_2xx";
        target = "http://10.0.0.54:5052/eth/v1/node/health";
      }
    ];
    uptimeScrapeConfig = target: {
      job_name = "uptime-${target.id}";
      metrics_path = "/probe";
      params = {module = [target.module];};
      static_configs = [
        {
          targets = [target.target];
          labels.target = target.label;
        }
      ];
      relabel_configs = [
        {
          source_labels = ["__address__"];
          target_label = "__param_target";
        }
        {
          source_labels = ["__param_target"];
          target_label = "instance";
        }
        {
          target_label = "__address__";
          replacement = "127.0.0.1:9115";
        }
      ];
    };
    missionDashboard = pkgs.writeText "mission-overview.json" (builtins.toJSON {
      annotations.list = [];
      editable = false;
      panels = [
        {
          datasource = {
            type = "prometheus";
            uid = "mission-prometheus";
          };
          fieldConfig.defaults = {
            color.mode = "thresholds";
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    color = "red";
                    text = "DOWN";
                  };
                  "1" = {
                    color = "green";
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = 0;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          fieldConfig.overrides = [];
          gridPos = {
            h = 7;
            w = 12;
            x = 0;
            y = 0;
          };
          options = {
            colorMode = "background";
            graphMode = "none";
            justifyMode = "center";
            orientation = "horizontal";
            reduceOptions = {
              calcs = ["lastNotNull"];
              fields = "";
              values = false;
            };
            textMode = "name";
          };
          targets = [
            {
              expr = ''probe_success{job=~"uptime-.*"}'';
              instant = true;
              refId = "A";
            }
          ];
          title = "Uptime Targets";
          type = "stat";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "mission-prometheus";
          };
          fieldConfig.defaults = {
            color.mode = "thresholds";
            decimals = 2;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = 0;
                }
                {
                  color = "yellow";
                  value = 95;
                }
                {
                  color = "green";
                  value = 99.9;
                }
              ];
            };
            unit = "percent";
          };
          fieldConfig.overrides = [];
          gridPos = {
            h = 7;
            w = 12;
            x = 12;
            y = 0;
          };
          options = {
            colorMode = "value";
            graphMode = "none";
            justifyMode = "center";
            orientation = "horizontal";
            reduceOptions = {
              calcs = ["lastNotNull"];
              fields = "";
              values = false;
            };
            textMode = "value_and_name";
          };
          targets = [
            {
              expr = ''avg_over_time(probe_success{job=~"uptime-.*"}[24h]) * 100'';
              instant = true;
              refId = "A";
            }
          ];
          title = "24h Availability";
          type = "stat";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "point-prometheus";
          };
          fieldConfig.defaults = {
            color.mode = "thresholds";
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    color = "red";
                    text = "DOWN";
                  };
                  "1" = {
                    color = "green";
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = 0;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          fieldConfig.overrides = [];
          gridPos = {
            h = 5;
            w = 6;
            x = 0;
            y = 7;
          };
          options = {
            colorMode = "background";
            graphMode = "none";
            justifyMode = "center";
            orientation = "auto";
            reduceOptions = {
              calcs = ["lastNotNull"];
              fields = "";
              values = false;
            };
            textMode = "value_and_name";
          };
          targets = [
            {
              expr = ''up{job="reth"}'';
              instant = true;
              refId = "A";
            }
          ];
          title = "Reth";
          type = "stat";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "point-prometheus";
          };
          fieldConfig.defaults = {
            color.mode = "thresholds";
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    color = "red";
                    text = "DOWN";
                  };
                  "1" = {
                    color = "green";
                    text = "UP";
                  };
                };
              }
            ];
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = 0;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          fieldConfig.overrides = [];
          gridPos = {
            h = 5;
            w = 6;
            x = 6;
            y = 7;
          };
          options = {
            colorMode = "background";
            graphMode = "none";
            justifyMode = "center";
            orientation = "auto";
            reduceOptions = {
              calcs = ["lastNotNull"];
              fields = "";
              values = false;
            };
            textMode = "value_and_name";
          };
          targets = [
            {
              expr = ''up{job="lighthouse"}'';
              instant = true;
              refId = "A";
            }
          ];
          title = "Lighthouse";
          type = "stat";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "point-prometheus";
          };
          fieldConfig.defaults = {
            color.mode = "thresholds";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = 0;
                }
                {
                  color = "green";
                  value = 1;
                }
              ];
            };
          };
          fieldConfig.overrides = [];
          gridPos = {
            h = 5;
            w = 6;
            x = 12;
            y = 7;
          };
          options = {
            colorMode = "value";
            graphMode = "area";
            justifyMode = "center";
            orientation = "auto";
            reduceOptions = {
              calcs = ["lastNotNull"];
              fields = "";
              values = false;
            };
            textMode = "value_and_name";
          };
          targets = [
            {
              expr = ''reth_network_connected_peers{instance="v3x-point"}'';
              instant = true;
              refId = "A";
            }
          ];
          title = "Reth Peers";
          type = "stat";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "point-prometheus";
          };
          fieldConfig.defaults = {
            color.mode = "thresholds";
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = 0;
                }
                {
                  color = "yellow";
                  value = 2;
                }
                {
                  color = "red";
                  value = 8;
                }
              ];
            };
          };
          fieldConfig.overrides = [];
          gridPos = {
            h = 5;
            w = 6;
            x = 18;
            y = 7;
          };
          options = {
            colorMode = "value";
            graphMode = "area";
            justifyMode = "center";
            orientation = "auto";
            reduceOptions = {
              calcs = ["lastNotNull"];
              fields = "";
              values = false;
            };
            textMode = "value_and_name";
          };
          targets = [
            {
              expr = "slotclock_present_slot - beacon_head_state_slot";
              instant = true;
              refId = "A";
            }
          ];
          title = "Beacon Slot Lag";
          type = "stat";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "mission-prometheus";
          };
          fieldConfig.defaults = {
            color.mode = "palette-classic";
            custom = {
              drawStyle = "line";
              fillOpacity = 15;
              lineWidth = 2;
              showPoints = "never";
            };
            unit = "s";
          };
          fieldConfig.overrides = [];
          gridPos = {
            h = 8;
            w = 24;
            x = 0;
            y = 12;
          };
          options = {
            legend = {
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              mode = "single";
              sort = "none";
            };
          };
          targets = [
            {
              expr = ''probe_duration_seconds{job=~"uptime-.*"}'';
              legendFormat = "{{target}}";
              refId = "A";
            }
          ];
          title = "Probe Duration";
          type = "timeseries";
        }
      ];
      refresh = "30s";
      schemaVersion = 41;
      tags = ["mission" "ethereum" "uptime"];
      time = {
        from = "now-24h";
        to = "now";
      };
      title = "Mission Overview";
      uid = "mission-overview";
      version = 1;
    });
    missionDashboardDirectory = pkgs.linkFarm "mission-dashboards" [
      {
        name = "overview.json";
        path = missionDashboard;
      }
    ];
  in {
    hardware.facter.reportPath = ./facter.json;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-mission";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";

    programs.niri.enable = true;

    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      retentionTime = "30d";
      scrapeConfigs = map uptimeScrapeConfig uptimeTargets;
    };

    services.prometheus.exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      configFile = pkgs.writeText "mission-blackbox.yml" (builtins.toJSON {
        modules = {
          http_2xx.prober = "http";
          tcp_connect.prober = "tcp";
        };
      });
    };

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
              options.path = missionDashboardDirectory;
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

    # Let niri-session provide the session PATH to Niri and its user services.
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
