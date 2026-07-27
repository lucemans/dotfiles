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
      requires = ["litellm.service" "hermes-ssh-agent.service"];
      after = ["litellm.service" "hermes-ssh-agent.service"];
      path = [
        pkgs.docker
        pkgs.gh
        pkgs.claude-code
        pkgs.openssh
      ];
    };

    # SSH agent for the hermes user — enables SSH + git signing
    systemd.services.hermes-ssh-agent = {
      description = "SSH agent for the hermes user";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      requires = ["sops-secrets-teapot_ssh_ed25519_key.service"];
      serviceConfig = {
        User = "hermes";
        Group = "hermes";
        ExecStart = "${pkgs.openssh}/bin/ssh-agent -a ${config.services.hermes-agent.stateDir}/.ssh-agent.sock";
        ExecStartPost = "${pkgs.openssh}/bin/ssh-add ${config.sops.secrets.teapot_ssh_ed25519_key.path}";
        Restart = "always";
        RestartSec = 5;
      };
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
        teapot_github_pat = {};
        teapot_ssh_ed25519_key = {
          path = "${config.services.hermes-agent.stateDir}/.ssh/id_ed25519";
          mode = "0600";
        };
        teapot_ssh_ed25519_public_key = {
          path = "${config.services.hermes-agent.stateDir}/.ssh/id_ed25519.pub";
          mode = "0644";
        };
      };

      templates."teapot_hermes_env" = {
        owner = "hermes";
        group = "hermes";
        mode = "0400";
        content = ''
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder.teapot_telegram_token}
          TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.teapot_telegram_allowed_users}
          LITELLM_API_KEY=${config.sops.placeholder.teapot_litellm_master_key}
          GH_TOKEN=${config.sops.placeholder.teapot_github_pat}
        '';
      };

      # SSH config for the hermes user
      templates."hermes_ssh_config" = {
        owner = "hermes";
        group = "hermes";
        mode = "0600";
        path = "${config.services.hermes-agent.stateDir}/.ssh/config";
        content = ''
          Host github.com
            IdentityFile ${config.sops.secrets.teapot_ssh_ed25519_key.path}
            IdentitiesOnly yes
            AddKeysToAgent yes
        '';
      };

      # Git signing key for the hermes user
      templates."hermes_git_signingkey" = {
        owner = "hermes";
        group = "hermes";
        mode = "0444";
        path = "${config.services.hermes-agent.stateDir}/.git-signingkey";
        content = "${config.sops.secrets.teapot_ssh_ed25519_key.path}";
      };

      # Git config for the hermes user — SSH signing enabled
      templates."hermes_gitconfig" = {
        owner = "hermes";
        group = "hermes";
        mode = "0600";
        path = "${config.services.hermes-agent.stateDir}/.gitconfig";
        content = ''
          [user]
            name = 418teapotcat
            email = 418teapotcat@users.noreply.github.com
          [commit]
            gpgFormat = ssh
          [gpg "ssh"]
            allowedSignersFile = ${config.sops.templates."hermes_git_allowed_signers".path}
          [gpg]
            format = ssh
        '';
      };

      # Allowed signers file for SSH signing
      templates."hermes_git_allowed_signers" = {
        owner = "hermes";
        group = "hermes";
        mode = "0644";
        path = "${config.services.hermes-agent.stateDir}/.ssh/allowed_signers";
        content = "* ${config.sops.secrets.teapot_ssh_ed25519_public_key.path}";
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
        # Wire SSH agent socket so git/gh CLI can use SSH auth
        SSH_AUTH_SOCK = "${config.services.hermes-agent.stateDir}/.ssh-agent.sock";
        # Wire SSH config for git over SSH
        GIT_SSH_COMMAND = "ssh -F ${config.sops.templates."hermes_ssh_config".path}";
      };
      extraDependencyGroups = ["messaging"];
      settings = {
        model = {
          provider = "custom";
          # litellm falls back to v3x-t/... automatically if mediabus is down
          # (router_settings.fallbacks in modules/services/llm).
          default = "v3x-m/qwen3.6-35b-a3b";
          base_url = "http://127.0.0.1:4000/v1";
          api_mode = "chat_completions";
          api_key = "\${LITELLM_API_KEY}";
          # Must match llama-server --ctx-size (modules/services/llm).
          # Without this hermes falls back to probing/registry lookups and
          # assumes ~256k, then blows past what llama-server actually serves.
          context_length = 131072;
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
          threshold = 0.5;
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
