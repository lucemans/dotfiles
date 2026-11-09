{inputs, ...}: let
  inherit (import ./topology.nix) code forge;
  inherit (import ../../network/services.nix) services;
in {
  flake.nixosModules.kettleRunner = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (config.sops) secrets templates;

    onHost = service: config.networking.hostName == service.host;
    codeUrl =
      if onHost code
      then "ws://127.0.0.1:${toString code.port}"
      else "wss://${services.code.name}";
    forgeUrl =
      if onHost forge
      then "http://127.0.0.1:${toString forge.port}"
      else "https://${services.forge.name}";

    agentConfigs = import ../../agent/configs;
    preferences = import ../../agent/configs/model-preferences.nix;

    omp = import ./omp.nix {
      inherit inputs lib pkgs;
      inferenceToken = templates.kettle_runner_inference_token.path;
    };

    agents =
      lib.mapAttrsToList (path: file: pkgs.writeText (baseNameOf path) file.text)
      ((import ../../agent/configs/general/subagents).files "omp" "agents")
      ++ omp.reviewers;

    k5f = inputs.kettle-forge.packages.${system}.k5f;
    planEnv = inputs.plan-env-md.packages.${system}.plan-env-md-mcp;
    planEnvCommand = lib.getExe' planEnv "plan-env-md-mcp";

    envFiles = [templates.kettle_runner_agent_env.path];
    extraPath = [k5f planEnv];

    # idk man python... why
    extraPathWithPython = extraPath ++ [pkgs.python3];
    planEnvConfig.".config/plan-env-md/config" = secrets.kettle_plan_env_config.path;

    kettleOmp =
      (import "${inputs.kettle-code}/nix/harnesses" {
        inherit pkgs;
        omp = null;
        codex = null;
        opencode = null;
      }).omp;
    ompNetworkDeny = kettleOmp.networkDeny;
  in {
    sops.secrets = {
      kettle_runner_key.mode = "0400";
      kettle_runner_launcher_token.mode = "0400";
      kettle_plan_env_config.mode = "0400";
      v3x_agent_token = {};
      v3x_inference_token = {};
    };

    sops.templates = {
      kettle_runner_agent_env = {
        mode = "0400";
        content = ''
          ANTHROPIC_AUTH_TOKEN="${config.sops.placeholder.v3x_agent_token}"
          ANTHROPIC_API_KEY="${config.sops.placeholder.v3x_agent_token}"
        '';
      };
      # Mounted into every run, so the runner user must be able to read it.
      kettle_runner_inference_token = {
        owner = "kettle-runner";
        mode = "0400";
        content = config.sops.placeholder.v3x_inference_token;
      };
    };

    services.kettle-runner = {
      enable = true;
      machine = lib.removePrefix "v3x-" config.networking.hostName;
      codeUrl = "${codeUrl}/api/v1/runners/connect";
      keyFile = secrets.kettle_runner_key.path;
      forge = {
        url = forgeUrl;
        launcherTokenFile = secrets.kettle_runner_launcher_token.path;
      };
      network.defaultMode = "internet";

      network.allow = map (svc: "${svc.name}:443") [services.inference services.agent services.search];
      devices.kvm.repos = ["open-lavatory/ecosystem"];
      kinds = {
        all.skills = lib.attrValues (agentConfigs.skillsOf pkgs agentConfigs.targets.kettle.all);
        all.systemPrompt = agentConfigs.promptOf pkgs agentConfigs.targets.kettle.all;
        coordinator.skills = lib.attrValues (agentConfigs.skillsOf pkgs agentConfigs.targets.kettle.coordinator);
        coordinator.systemPrompt = agentConfigs.promptOf pkgs agentConfigs.targets.kettle.coordinator;
        triage.systemPrompt = agentConfigs.promptOf pkgs agentConfigs.targets.kettle.triage;
      };

      harnesses.omp = {
        enable = true;
        inherit agents;
        settings = {
          modelRoles = {
            default = "${preferences.openai_luna}:high";
            tiny = preferences.openai_luna;
            smol = preferences.anthropic_haiku;
            task = preferences.anthropic_sonnet;
          };
          # compaction.modelThresholds = {
          #   "anthropic/claude-opus-5-5" = "f300000";
          #   "openai/gpt-6.1-sol" = "f250000";
          #   "openai/gpt-6.1-terra" = "f250000";
          # };
          providers.maxInFlightRequests = {
            anthropic = 3;
            openai = 3;
            moonshot = 3;
            meta = 3;
          };
          advisor.enabled = false;
          symbolPreset = "nerd";
          retry.fallbackChains.web = ["web/hosted" "web/searxng"];
          searxng.endpoint = "https://${services.search.name}";
          secrets.enabled = true;
          title.generator = "tiny";

          setupVersion = 2;
          dev.autoqaConsent = "denied";
        };
        mcpServers.plan_env = {
          type = "stdio";
          command = planEnvCommand;
        };
        files =
          {
            ".omp/agent/models.yml" = "${omp.models}";
          }
          // planEnvConfig;
        inherit envFiles extraPath;
        secretFiles = [templates.kettle_runner_inference_token.path];
      };

      harnesses.codex = {
        enable = true;
        package = pkgs.fetchzip {
          name = "codex-0.166.0-alpha.2";
          url = "https://github.com/openai/codex/releases/download/rust-v0.166.0-alpha.2/codex-package-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-n1hqtAaXKeOuCsWmFKcSMnSpwuuy5cs+9lnumHrdMAo=";
          stripRoot = false;
          meta.mainProgram = "codex";
          meta.platforms = ["x86_64-linux"];
        };
        inherit envFiles;
        extraPath = extraPathWithPython;
        extraDeny = ompNetworkDeny;
        settings = {
          model_provider = "v3x";
          model = "gpt-6.1-sol";
          model_providers.v3x = {
            name = "v3x agent gateway";
            base_url = "https://${services.agent.name}/v1";
            env_key = "ANTHROPIC_API_KEY";
            wire_api = "responses";
          };
          mcp_servers = {
            plan_env.command = planEnvCommand;
          };
        };
        files = planEnvConfig;
      };
      harnesses.opencode = {
        enable = true;
        inherit envFiles;
        extraPath = extraPathWithPython;
        extraDeny = ompNetworkDeny;
        settings = {
          share = "disabled";
          autoupdate = false;
          disabled_providers = ["anthropic"];
          provider.openai.options = {
            baseURL = "https://${services.agent.name}/v1";
            apiKey = "{env:ANTHROPIC_API_KEY}";
          };
          mcp = {
            plan_env = {
              type = "local";
              command = [planEnvCommand];
            };
          };
        };
        files = planEnvConfig;
      };

      harnesses.muse = {
        enable = true;
        inherit envFiles;
        extraPath = extraPathWithPython;
        extraDeny = ompNetworkDeny;
        env.MUSE_API_KEY_ENV = "ANTHROPIC_API_KEY";
        settings.endpoint_transport.base_url = "https://${services.agent.name}/v1";
        mcpServers.plan_env.command = planEnvCommand;
        files = planEnvConfig;
      };

      harnesses.claude = {
        enable = true;
        inherit (inputs.kettle-code.legacyPackages.${system}.harnesses.claude) package;
        inherit envFiles;
        extraPath = extraPathWithPython;
        extraDeny = ompNetworkDeny;
        env = {
          ANTHROPIC_BASE_URL = "https://${services.agent.name}";
          CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1";
          ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-5-5";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-5-5";
          ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-5-5";
        };
        settings = {
          permissions.defaultMode = "bypassPermissions";
          feedbackDrafts = "off";
        };
        files = planEnvConfig;
      };
    };
  };
}
