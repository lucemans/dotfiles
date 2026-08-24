{...}: let
  apiPort = 6853;
  dashboardPort = 9119;
in {
  flake.nixosModules.teapotHermes = {
    config,
    pkgs,
    ...
  }: {
    systemd.services.hermes-agent = {
      requires = ["litellm.service"];
      after = ["litellm.service"];
      path = [
        pkgs.docker
        pkgs.gh
        pkgs.claude-code
        pkgs.openssh
      ];
    };

    users.users.hermes = {
      isNormalUser = true;
      extraGroups = ["docker"];
    };

    sops = {
      age.keyFile = "/home/luc/.config/sops/age/keys.txt";
      # defaultSopsFile = ../../secrets/418.sops.yaml;
      secrets = {
        teapot_telegram_token = {};
        teapot_telegram_allowed_users = {};
        teapot_mattermost_url = {};
        teapot_mattermost_token = {};
        teapot_mattermost_allowed_users = {};
        teapot_github_pat = {};
        teapot_ssh_ed25519_key = {
          path = "${config.services.hermes-agent.stateDir}/.ssh/id_ed25519";
          mode = "0600";
          owner = "hermes";
          group = "hermes";
        };
        teapot_ssh_ed25519_public_key = {
          path = "${config.services.hermes-agent.stateDir}/.ssh/id_ed25519.pub";
          mode = "0644";
          owner = "hermes";
          group = "hermes";
        };
      };

      templates."teapot_hermes_env" = {
        owner = "hermes";
        group = "hermes";
        mode = "0400";
        content = ''
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder.teapot_telegram_token}
          TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.teapot_telegram_allowed_users}
          MATTERMOST_URL=${config.sops.placeholder.teapot_mattermost_url}
          MATTERMOST_TOKEN=${config.sops.placeholder.teapot_mattermost_token}
          MATTERMOST_ALLOWED_USERS=${config.sops.placeholder.teapot_mattermost_allowed_users}
          LITELLM_API_KEY=${config.sops.placeholder.teapot_litellm_master_key}
          GH_TOKEN=${config.sops.placeholder.teapot_github_pat}
          GITHUB_TOKEN=${config.sops.placeholder.teapot_github_pat}
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [
      apiPort
      dashboardPort
    ];
    systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = 210;
    services.hermes-agent = {
      enable = false;
      user = "hermes";
      group = "hermes";
      createUser = true;
      stateDir = "/var/lib/hermes";
      container.enable = false;
      environmentFiles = [config.sops.templates."teapot_hermes_env".path];
      environment = {
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = "0.0.0.0";
        API_SERVER_PORT = toString apiPort;
      };
      extraDependencyGroups = ["messaging"];
      settings = {
        model = {
          provider = "custom";
          default = "v3x-m/qwen3.6-35b-a3b";
          base_url = "http://127.0.0.1:4000/v1";
          api_mode = "chat_completions";
          api_key = "\${LITELLM_API_KEY}";
          context_length = 98304;
        };
        toolsets = ["all"];
        max_turns = 100;
        terminal = {
          backend = "local";
        };
        web = {
          backend = "ddgs";
        };
        compression = {
          enabled = true;
          threshold = 0.8;
          summary_model = "v3x-m/qwen3.6-35b-a3b";
        };
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
        };
        display = {
          compact = false;
          personality = "technical";
        };
        agent = {
          max_turns = 150;
          verbose = false;
        };
        plugins.enabled = ["hermes-lcm" "rtk-rewrite" "web-ddgs"];
        # stt = {
        #   provider = "openai";
        #   openai.model = "mistralai/Voxtral-Mini-4B-Realtime-2602";
        #   openai.base_url = "https://...";
        #   openai.api_key = "\${}";
        # };
        gateway = {
          platforms = {
            telegram = {
              enable = true;
              extra = {
                status_indicator = true;
                status_online = "🟢 Online";
                status_offline = "🔴 Offline";
              };
            };
            mattermost = {
              enable = true;
            };
          };
        };
      };
      mcpServers.github = {
        command = "npx";
        args = [
          "-y"
          "@modelcontextprotocol/server-github"
        ];
        env = {
          GITHUB_PERSONAL_ACCESS_TOKEN = "\${GH_TOKEN}";
        };
      };
      extraPlugins = [
        (pkgs.fetchFromGitHub {
          owner = "stephenschoettler";
          repo = "hermes-lcm";
          rev = "v0.20.0";
          hash = "sha256-yJ1Nn+su7YbKd+cgVOizXChzLbKHqTprSprF1p9/HYk=";
        })
      ];
      extraPythonPackages = [
        (pkgs.python312Packages.buildPythonPackage {
          pname = "rtk-hermes";
          version = "1.2.3";
          src = pkgs.fetchFromGitHub {
            owner = "ogallotti";
            repo = "rtk-hermes";
            rev = "v1.2.3";
            hash = "sha256-7YRW6PODrCapfYLFn3DvgHAEME//RGC48GQt+s9ot0s=";
          };
          format = "pyproject";
          build-system = [pkgs.python312Packages.setuptools];
        })
      ];

      addToSystemPackages = true;
      restart = "no";
      restartSec = 5;
    };

    systemd.services.hermes-dashboard = {
      description = "Hermes Agent Dashboard";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "hermes-agent.service"];
      wants = ["network-online.target"];
      requires = ["hermes-agent.service"];

      environment = {
        HOME = "/var/lib/hermes";
        HERMES_HOME = "/var/lib/hermes/.hermes";
        HERMES_MANAGED = "true";
      };

      serviceConfig = {
        User = "hermes";
        Group = "hermes";
        WorkingDirectory = "/var/lib/hermes/workspace";
        ExecStart = "${config.services.hermes-agent.package}/bin/hermes dashboard --skip-build --host 0.0.0.0 --port ${toString dashboardPort} --no-open";
        Restart = "always";
        RestartSec = 10;
        NoNewPrivileges = true;
      };

      path = [
        config.services.hermes-agent.package
        pkgs.bash
      ];
    };

    # systemd.tmpfiles.rules = [
    #   "Z /var/lib/hermes/.hermes - hermes hermes -"
    #   "Z /var/lib/hermes/.hermes/jobs - hermes hermes -"
    #   "L+ /var/lib/hermes/.hermes/SOUL.md - - - - ${./hermes/SOUL.md}"
    # ];
  };
}
