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
      path = [pkgs.docker];
    };
    users.users.hermes = {
      extraGroups = ["docker"];
    };

    sops = {
      age.keyFile = "/home/luc/.config/sops/age/keys.txt";
      # defaultSopsFile = ../../secrets/418.sops.yaml;
      secrets = {
        teapot_telegram_token = {};
        teapot_telegram_allowed_users = {};
      };
      templates."teapot_hermes_env" = {
        owner = "hermes";
        group = "hermes";
        mode = "0400";
        content = ''
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder.teapot_telegram_token}
          TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.teapot_telegram_allowed_users}
          LITELLM_API_KEY=${config.sops.placeholder.teapot_litellm_master_key}
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [
      apiPort
      dashboardPort
    ];
    systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = 210;
    services.hermes-agent = {
      enable = true;
      user = "hermes";
      group = "hermes";
      createUser = true;
      stateDir = "/var/lib/hermes";
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
          default = "deepseek/deepseek-v4-pro";
          base_url = "http://127.0.0.1:4000/v1";
          api_mode = "chat_completions";
          api_key = "\${LITELLM_API_KEY}";
        };
        toolsets = ["all"];
        max_turns = 100;
        terminal = {
          backend = "docker";
        };
        web = {
          backend = "ddgs";
        };
        compression = {
          enabled = true;
          threshold = 0.5;
          summary_model = "deepseek/deepseek-v4-pro";
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
        # stt = {
        #   provider = "openai";
        #   openai.model = "mistralai/Voxtral-Mini-4B-Realtime-2602";
        #   openai.base_url = "https://...";
        #   openai.api_key = "\${}";
        # };
      };
      # mcpServers.github = {
      #   command = "npx";
      #   args = [
      #     "-y"
      #     "@modelcontextprotocol/server-github"
      #   ];
      #   env = {
      #     GITHUB_PERSONAL_ACCESS_TOKEN = "\${GITHUB_PERSONAL_ACCESS_TOKEN}";
      #   };
      # };

      addToSystemPackages = true;
      restart = "no";
      restartSec = 5;
    };

    # Dashboard web UI — separate process from the gateway
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
