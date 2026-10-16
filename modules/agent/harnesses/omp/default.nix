{inputs, ...}: {
  flake.nixosModules.omp = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (import ../../../network/services.nix) services;

    # OMP takes a subagent's model from its definition, never from the task
    # call. A `^model` mention in the prompt covers a general-purpose worker on
    # any model, so only reviewers are pinned here. Each reuses the bundled
    # `reviewer` prompt of the pinned OMP, so only the model differs.
    pinned = {
      kimi = "anthropic/kimi-k3-256k";
      muse-wonder = "anthropic/muse-wonder-1.0";
      muse-spark = "anthropic/muse-spark-1.3";
    };
    prompts = "${inputs.omp}/packages/coding-agent/src/prompts/agents";
    reviewer = builtins.readFile "${prompts}/reviewer.md";
    reviewerFields = [
      "name: reviewer\n"
      "description: \"Code review specialist for quality/security analysis\"\n"
      "model: \"@slow\"\n"
    ];
    agents =
      lib.concatMapAttrs (name: model: {
        ".omp/agent/agents/${name}-reviewer.md".text = assert lib.assertMsg (lib.all (field: lib.hasInfix field reviewer) reviewerFields)
        "omp: the bundled reviewer.md frontmatter changed, update reviewerFields";
          builtins.replaceStrings reviewerFields [
            "name: ${name}-reviewer\n"
            "description: ${builtins.toJSON "Code review specialist for quality/security analysis on ${model}"}\n"
            "model: ${builtins.toJSON model}\n"
          ]
          reviewer;
      })
      pinned;
  in {
    home-manager.users.luc.home.file =
      agents
      // (import ../../subagents).files "omp" ".omp/agent/agents"
      // {
        ".omp/agent/themes/titanium-v3x.json".source = ./titanium-v3x.json;
        ".omp/agent/commands/sicko.md".text = ''
          Spawn exactly one `comment-sicko` task. Its assignment is the scope only: $ARGUMENTS
          With no arguments, pass an empty scope; the agent finds the uncommitted diff, or the last commit when the tree is clean.
          Do not restate review criteria, verdict formats, or acceptance rules; the agent carries its own. Relay its report unchanged.
        '';
      };

    agentRuntime.harnesses.omp = let
      mcp = {
        path = ".omp/agent/mcp.json";
        key = "mcpServers";
        servers =
          lib.mapAttrs (
            _: s:
              (
                if s ? url
                then
                  {
                    type = "http";
                    inherit (s) url;
                  }
                  // lib.optionalAttrs (s ? bearer) {
                    headers.Authorization = "!${pkgs.coreutils}/bin/printf 'Bearer %s' \"$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg s.bearer})\"";
                  }
                else {
                  type = "stdio";
                  inherit (s) command;
                }
              )
              // lib.optionalAttrs (s.timeout != null) {inherit (s) timeout;}
          )
          config.agentRuntime.servers;
      };
      models = pkgs.writeText "omp-models.yml" (builtins.toJSON {
        providers = {
          anthropic = {
            baseUrl = "https://${services.agent.name}";
            api = "anthropic-messages";
            apiKey = "!${pkgs.coreutils}/bin/printenv ANTHROPIC_API_KEY";
            modelOverrides =
              {
                "claude-fable-5-1".thinking = {
                  mode = "anthropic-adaptive";
                  efforts = ["low" "medium" "high" "xhigh" "max"];
                  supportsDisplay = true;
                };
              }
              // lib.genAttrs ["muse-wonder-1.0" "muse-wonder-1.0-contributor" "muse-spark-1.3"] (_: {
                thinking = {
                  mode = "anthropic-adaptive";
                  efforts = ["minimal" "low" "medium" "high" "xhigh" "max"];
                  requiresEffort = true;
                };
              });
            discovery.type = "openai-models-list";
            # Discovery lists these without their real context limits or
            # modalities, so both are stated here until the gateway reports
            # them. A model without `image` input gets image metadata only.
            models =
              map (id: {
                inherit id;
                input = ["text" "image"];
                contextWindow = 1050000;
                maxTokens = 128000;
              }) ["gpt-5.6-luna" "gpt-5.6-terra" "gpt-5.6-sol" "gpt-6-luna" "gpt-6-sol" "gpt-6.1-sol" "gpt-6-astra" "claude-opus-5-5"]
              ++ [
                {
                  id = "kimi-k3-256k";
                  input = ["text" "image"];
                  contextWindow = 256000;
                  maxTokens = 128000;
                }
              ]
              ++ map (id: {inherit id;}) ["muse-wonder-1.0" "muse-spark-1.3"];
          };
          v3x-inference = {
            baseUrl = "https://${services.inference.name}/v1";
            api = "openai-completions";
            apiKey = "!${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.sops.secrets.v3x_inference_token.path}";
            authHeader = true;
            discovery.type = "litellm";
          };
        };
      });
      settings = pkgs.writeText "omp-settings.yml" ''
        theme:
          dark: titanium-v3x
        # Use the shared `playwright` MCP server from the base toolset for the
        # browser, exactly like the claude-code and opencode harnesses. OMP's
        # built-in browser is disabled because its native "freeze owned browser
        # tabs at turn settle" step issues a synchronous CDP round-trip on the
        # main thread with no timeout; when that browser daemon wedges it locks
        # up the whole agent (same class of main-thread stall as the old git
        # subprocess issue).
        browser:
          enabled: false
        advisor:
          enabled: false
        providers:
          maxInFlightRequests:
            anthropic: 3
        # The `web` role itself sits in each profile's role overlay.
        retry:
          fallbackChains:
            web: [web/hosted]
        task:
          structured: true
        secrets:
          enabled: true
        title:
          generator: tiny
        searxng:
          endpoint: https://search.v3x.host
        startup:
          checkUpdate: false
        marketplace:
          autoUpdate: "off"
        symbolPreset: nerd
      '';

      # A profile is a role map. A fresh session starts on the profile's
      # default model; a resumed one keeps the model it recorded, which is
      # also how `agent` finds the profile that owns a session. The toolsets
      # extension records the session's toolsets the same way.
      profile = entry:
        entry
        // {
          command = [
            "omp"
            "--config"
            "${settings}"
            "--config"
            "${pkgs.writeText "omp-roles-${entry.name}.yml" (builtins.toJSON {modelRoles = {inherit vision web;} // entry.modelRoles;})}"
            "--extension"
            "${./agent-toolsets.ts}"
            "--extension"
            "${./github-urls.ts}"
            "--extension"
            "${./git-hint.ts}"
            "--extension"
            "${./code-blocks.ts}"
          ];
          # A profile with a catalog leaves --model to the picked entry.
          start = lib.optionals (!(entry ? catalog)) ["--model" "@default"];
        };

      tiny = "v3x-inference/v3x-m/minicpm5-2b";
      # Answers `read <image>?q=` for a model that takes no images. Unset, OMP
      # falls back to a built-in model the gateway does not route.
      vision = "anthropic/claude-opus-5-5";
      # Our SearXNG first, then the session model's own hosted search.
      web = "web/searxng";
    in {
      glyph = "󰚩";
      color = "189;147;249";
      blurb = "Oh My Pi";
      logo = ../../icons/omp.png;
      package = inputs.omp.packages.${pkgs.stdenv.hostPlatform.system}.default;
      inherit models mcp;
      profiles = map profile [
        {
          name = "gpt";
          glyph = "";
          color = "16;163;127";
          blurb = "OpenAI";
          logo = ../../icons/openai.png;
          modelRoles = {
            default = "anthropic/gpt-6.1-sol";
            inherit tiny;
            smol = "anthropic/gpt-6-luna";
            slow = "anthropic/gpt-6-astra";
          };
        }
        {
          name = "claude";
          glyph = "󰦣";
          color = "217;119;87";
          blurb = "Anthropic";
          logo = ../../icons/claude.png;
          modelRoles = {
            default = "anthropic/claude-opus-5-5";
            inherit tiny;
            smol = "anthropic/claude-opus-5-5";
            slow = "anthropic/claude-fable-5-1";
          };
        }
        {
          name = "kimi";
          glyph = "";
          color = "248;248;242";
          blurb = "Moonshot";
          logo = ../../icons/kimi.png;
          modelRoles = {
            default = "anthropic/kimi-k3-256k";
            inherit tiny;
            smol = "anthropic/kimi-k3-256k";
            slow = "anthropic/kimi-k3-256k";
          };
        }
        {
          name = "meta";
          glyph = "∞";
          color = "0;129;251";
          blurb = "Meta";
          logo = ../../icons/meta.png;
          modelRoles = {
            default = "anthropic/muse-wonder-1.0";
            inherit tiny;
            smol = "anthropic/muse-spark-1.3";
            slow = "anthropic/muse-wonder-1.0";
          };
        }
        {
          name = "local";
          glyph = "";
          color = "80;250;123";
          blurb = "v3x-inference";
          logo = ../../icons/local.png;
          modelRoles = {
            default = "v3x-inference/v3x-m/qwen3.8-27b";
            inherit tiny;
            smol = "v3x-inference/v3x-t/qwen3.6-35b-a3b";
            slow = "v3x-inference/v3x-m/qwen3.8-27b";
          };
        }
        {
          name = "openrouter";
          glyph = "";
          color = "148;163;184";
          blurb = "OpenRouter";
          logo = ../../icons/openrouter.png;
          # `default` is deliberately absent: the picked OpenRouter model
          # arrives as --model, so a stale fallback here could silently win
          # instead.
          modelRoles = {
            inherit tiny;
            smol = "anthropic/gpt-6-luna";
            slow = "anthropic/gpt-6-astra";
          };
          # LiteLLM is the authority, not OpenRouter's public catalog: a
          # model absent from the proxy cannot be routed, so it must not be
          # offered. Wildcard routes are expanded into concrete ids.
          catalog = {
            url = "https://${services.inference.name}/v1/models?return_wildcard_routes=true";
            token = config.sops.secrets.v3x_inference_token.path;
            prefix = "openrouter/";
            qualify = "v3x-inference/";
          };
        }
      ];
    };
  };
}
