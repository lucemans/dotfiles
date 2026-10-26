{inputs, ...}: let
  inherit (import ./topology.nix) code forge;
  inherit (import ../../network/topology.nix) hub;
  inherit (import ../../network/hosts.nix) hosts;
  inherit (import ../../network/services.nix) services;
in {
  # Needs inputs.kettle-code.nixosModules.default, and the machine's public
  # key in k5c's machines.
  flake.nixosModules.kettleRunner = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (config.sops) secrets templates;

    # k5r sends its tokens only over TLS or loopback.
    onHost = service: config.networking.hostName == service.host;
    codeUrl =
      if onHost code
      then "ws://127.0.0.1:${toString code.port}"
      else "wss://${services.code.name}";
    forgeUrl =
      if onHost forge
      then "http://127.0.0.1:${toString forge.port}"
      else "https://${services.forge.name}";

    # Luc's skills, read from the desktop setup. Kettle Code adds its own
    # `whereami` for the run sandbox, `visuals` and `browser`. decision-log
    # and skill-improve write to host paths a run does not have, and the
    # desktop whereami describes the desktop sandbox. The `why` skill is
    # replaced by a variant that reads the forge with k5f; Kettle Code names
    # each skill after its store name, so this derivation is named `why`.
    skillsDir = ../../agent/skills;
    leftOut = ["decision-log" "skill-improve" "whereami" "why"];
    why = pkgs.runCommand "why" {} ''
      cp -r ${skillsDir + "/why"} $out
      chmod -R u+w $out
      patch -d $out -p1 < ${./why-k5r.patch}
    '';
    skills =
      lib.mapAttrsToList (name: _: skillsDir + "/${name}")
      (lib.filterAttrs (name: type: type == "directory" && !lib.elem name leftOut) (builtins.readDir skillsDir))
      ++ [why];

    # Its models.yml calls this host's coreutils by store path. A run has that
    # path because kettle-code's manifest puts the same coreutils on PATH.
    omp = import ./omp.nix {
      inherit inputs lib pkgs;
      inferenceToken = templates.kettle_runner_inference_token.path;
    };

    # comment-sicko as the desktop renders it for OMP, then the reviewers.
    agents =
      lib.mapAttrsToList (path: file: pkgs.writeText (baseNameOf path) file.text)
      ((import ../../agent/subagents).files "omp" "agents")
      ++ omp.reviewers;

    k5f = inputs.kettle-forge.packages.${system}.k5f;
    planEnv = inputs.plan-env-md.packages.${system}.plan-env-md-mcp;
    planEnvCommand = lib.getExe' planEnv "plan-env-md-mcp";

    envFiles = [templates.kettle_runner_agent_env.path];
    extraPath = [k5f planEnv];
    # Kettle Code's OMP brings python3 itself; the other harnesses get it here.
    extraPathWithPython = extraPath ++ [pkgs.python3];
    planEnvConfig.".config/plan-env-md/config" = secrets.kettle_plan_env_config.path;

    # Kettle Code's OMP DNS deny list (r.jina.ai and the third-party startup
    # catalogs) and Playwright server, for the other harnesses too.
    kettleOmp =
      (import "${inputs.kettle-code}/nix/harnesses" {
        inherit pkgs;
        omp = null;
        codex = null;
        opencode = null;
      }).omp;
    ompNetworkDeny = kettleOmp.networkDeny;
    inherit (kettleOmp.mcpServers) playwright;
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
      # k5r filters by address and port, so runs reach every service the hub's
      # proxy serves to this host: the model gateway, v3x-inference, SearXNG.
      network.allow = ["${hosts.${hub}.address}:443"];

      # Kettle Code's own OMP (18.11.3 with its patches); these settings render
      # over Kettle Code's run defaults.
      harnesses.omp = {
        enable = true;
        inherit skills agents;
        settings = {
          modelRoles = {
            default = "openai/gpt-6-luna:high";
            tiny = "openai/gpt-6-luna";
            smol = "anthropic/claude-haiku-5-5";
            task = "anthropic/claude-sonnet-5-5";
          };
          compaction.modelThresholds = {
            "anthropic/claude-opus-5-5" = "f300000";
            "openai/gpt-6.1-sol" = "f250000";
          };
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
          # First-run answers, as in the playtest: setup done, auto-QA
          # reports declined.
          setupVersion = 2;
          dev.autoqaConsent = "denied";
        };
        mcpServers.plan_env = {
          type = "stdio";
          command = planEnvCommand;
        };
        # Only plan-env's config is secret; models.yml goes through
        # LoadCredential= all the same.
        files =
          {
            ".omp/agent/models.yml" = "${omp.models}";
          }
          // planEnvConfig;
        inherit envFiles extraPath;
        secretFiles = [templates.kettle_runner_inference_token.path];
      };

      # OMP's sub-agents are Markdown and codex reads `*.toml` role files, so
      # codex gets none.
      harnesses.codex = {
        enable = true;
        inherit skills envFiles;
        extraPath = extraPathWithPython;
        extraDeny = ompNetworkDeny;
        settings = {
          model_provider = "v3x";
          model = "gpt-6.1-sol";
          # The model gateway. The key is ANTHROPIC_API_KEY from the agent env
          # file; the config only names the variable.
          model_providers.v3x = {
            name = "v3x agent gateway";
            base_url = "https://${services.agent.name}/v1";
            env_key = "ANTHROPIC_API_KEY";
            wire_api = "responses";
          };
          mcp_servers = {
            playwright = {inherit (playwright) command args;};
            plan_env.command = planEnvCommand;
          };
        };
        # plan-env's config is secret, so it is a file, not a setting.
        files = planEnvConfig;
      };

      # Anthropic models run on OMP or Claude Code, never here.
      harnesses.opencode = {
        enable = true;
        inherit skills envFiles;
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
            playwright = {
              type = "local";
              command = [playwright.command] ++ playwright.args;
            };
            plan_env = {
              type = "local";
              command = [planEnvCommand];
            };
          };
        };
        files = planEnvConfig;
      };

      # The package Kettle Code's tests record, built with its own nixpkgs.
      # Kettle Code pins no models, so the three aliases are pinned here.
      # claude-agent-acp takes no approval flag; only settings.json turns
      # permission prompts off.
      harnesses.claude = {
        enable = true;
        inherit (inputs.kettle-code.legacyPackages.${system}.harnesses.claude) package;
        inherit skills envFiles;
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
