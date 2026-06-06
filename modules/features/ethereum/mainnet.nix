{ self, inputs, ... }:
{
  flake.nixosModules.ethereumMainnet =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      services.ethereum.reth.mainnet = {
        enable = true;
        package = pkgs.reth;
        openFirewall = true;
        args = {
          full = true;
          chain = "mainnet";
          http = {
            enable = true;
            addr = "0.0.0.0";
            api = [
              "net"
              "web3"
              "eth"
            ];
          };
          authrpc = {
            jwtsecret = "/var/lib/reth-mainnet/jwt.hex";
          };
          metrics = {
            enable = true;
          };
        };
      };

      services.ethereum.lighthouse-beacon.mainnet = {
        enable = true;
        openFirewall = true;
        args = {
          network = "mainnet";
          execution-jwt = "/var/lib/reth-mainnet/jwt.hex";
          checkpoint-sync-url = "https://checkpointz.pietjepuk.net";
          genesis-state-url = "https://checkpointz.pietjepuk.net";
          metrics = {
            enable = true;
          };
        };
      };

      services.prometheus = {
        enable = true;
        port = 9090;
        listenAddress = "127.0.0.1";
        retentionTime = "30d";
        scrapeConfigs = [
          {
            job_name = "reth";
            static_configs = [
              {
                targets = [ "127.0.0.1:6060" ];
                labels = {
                  instance = "v3x-point";
                };
              }
            ];
          }

          {
            job_name = "lighthouse";
            static_configs = [
              {
                targets = [ "127.0.0.1:5054" ];
                labels = {
                  instance = "v3x-point";
                };
              }
            ];
          }
        ];
      };

      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          server = {
            http_listen_address = "127.0.0.1";
            http_listen_port = 3100;
            grpc_listen_port = 0;
          };

          common = {
            path_prefix = "/var/lib/loki";
            storage.filesystem = {
              chunks_directory = "/var/lib/loki/chunks";
              rules_directory = "/var/lib/loki/rules";
            };
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
          };

          schema_config.configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];

          limits_config = {
            retention_period = "14d";
          };

          compactor = {
            working_directory = "/var/lib/loki/compactor";
            retention_enabled = true;
            delete_request_store = "filesystem";
          };
        };
      };

      services.alloy = {
        enable = true;
        configPath = "/etc/alloy";
      };

      environment.etc."alloy/ethereum.alloy".text = ''
        loki.source.journal "systemd" {
                max_age = "24h"

                labels = {
                        job = "systemd-journal",
                        host = "v3x-point",
                }

        relabel_rules = loki.relabel.journal.rules
                forward_to = [loki.write.local.receiver]
        }

        loki.relabel "journal" {
                rule {
                        source_labels = ["__journal__systemd_unit"]
                        target_label = "unit"
                }

                rule {
                        source_labels = ["__journal__hostname"]
                        target_label = "host"
                }

                forward_to = []
        }

        loki.write "local" {
                endpoint {
                        url = "http://127.0.0.1:3100/loki/api/v1/push"
                }
        }
      '';

      services.grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "0.0.0.0";
            http_port = 3000;
            domain = "v3x-point";
          };
          security.secret_key = "test";
          analytics.reporting_enabled = false;
        };

        provision = {
          enable = true;
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:9090";
              isDefault = true;
            }
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:3100";
            }
          ];
        };
      };

      environment.systemPackages =
        (with pkgs; [
          grafana-alloy
        ])
        ++ (with inputs.ethereum-nix.packages.${pkgs.system}; [
          lighthouse
          reth
        ]);
    };
}
