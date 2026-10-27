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
    preferences = import ../../configs/model-preferences.nix;

    pinned = {
      kimi = "moonshot/kimi-k3-256k";
      muse-wonder = "meta/muse-wonder-1.0";
      muse-spark = "meta/muse-spark-1.3";
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
      // (import ../../configs/general/subagents).files "omp" ".omp/agent/agents"
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
      gateway = {
        baseUrl = "https://${services.agent.name}";
        api = "anthropic-messages";
        apiKey = "!${pkgs.coreutils}/bin/printenv ANTHROPIC_API_KEY";
        auth = "apiKey";
      };
      models = pkgs.writeText "omp-models.yml" (builtins.toJSON {
        providers = {
          openai =
            gateway
            // {
              discovery = {
                type = "openai-models-list";
                ownedBy = ["openai"];
                authoritative = true;
              };
              # CLIProxyAPI lists these as chat rows but serves them on its OpenAI image route.
              models = map (id: {
                inherit id;
                api = "openai-images";
                baseUrl = "${gateway.baseUrl}/v1";
              }) ["gpt-image-1.5" "gpt-image-2" "gpt-image-2.5" "gpt-image-2.5-flare" "gpt-image-2.5-sunburst"];
              modelOverrides =
                lib.genAttrs ["gpt-5.6-luna" "gpt-5.6-terra" "gpt-5.6-sol" "gpt-6-luna" "gpt-6-sol" "gpt-6.1-sol" "gpt-6-astra"] (_: {
                  input = ["text" "image"];
                  contextWindow = 1050000;
                  maxTokens = 128000;
                })
                // {
                  "gpt-6.1-terra" = {
                    input = ["text" "image"];
                    contextWindow = 1050000;
                    maxTokens = 128000;
                    reasoning = true;
                    thinking = {
                      mode = "effort";
                      efforts = ["low" "medium" "high" "xhigh" "max"];
                    };
                    compat.supportsReasoningEffort = true;
                  };
                };
            };
          anthropic =
            gateway
            // {
              discovery = {
                type = "openai-models-list";
                ownedBy = ["anthropic"];
                authoritative = true;
              };
              modelOverrides = {
                "claude-opus-5-5" = {
                  input = ["text" "image"];
                  contextWindow = 1050000;
                  maxTokens = 128000;
                };
                "claude-fable-5-1".thinking = {
                  mode = "anthropic-adaptive";
                  efforts = ["low" "medium" "high" "xhigh" "max"];
                  supportsDisplay = true;
                };
              };
            };
          moonshot =
            gateway
            // {
              discovery = {
                type = "openai-models-list";
                ownedBy = ["moonshot"];
                authoritative = true;
              };
              modelOverrides = let
                # K3.1 Pro refuses `thinking.type = "disabled"` (400 at the gateway), so
                # requiresEffort clamps thinking-off to the lowest effort.
                k31 = name: {
                  inherit name;
                  contextWindow = 1048576;
                  maxTokens = 131072;
                  reasoning = true;
                  thinking = {
                    mode = "anthropic-adaptive";
                    efforts = ["low" "high" "max"];
                    requiresEffort = true;
                  };
                  input = ["text" "image"];
                };
              in {
                "kimi-k3-256k" = {
                  contextWindow = 256000;
                  maxTokens = 128000;
                };
                "kimi-k3.1-pro" = k31 "Kimi K3.1 Pro";
                "kimi-k3.1-pro-highspeed" = k31 "Kimi K3.1 Pro Highspeed";
              };
            };
          meta =
            gateway
            // {
              discovery = {
                type = "openai-models-list";
                ownedBy = ["meta"];
                authoritative = true;
              };
              modelOverrides = lib.genAttrs ["muse-wonder-1.0" "muse-wonder-1.0-contributor" "muse-spark-1.3"] (_: {
                thinking = {
                  mode = "anthropic-adaptive";
                  efforts = ["minimal" "low" "medium" "high" "xhigh" "max"];
                  requiresEffort = true;
                };
              });
            };
          v3x-inference = {
            baseUrl = "https://${services.inference.name}/v1";
            api = "openai-completions";
            apiKey = "!${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.sops.secrets.v3x_inference_token.path}";
            authHeader = true;
            discovery.type = "litellm";
            # LiteLLM discovery drops non-chat modes, so those rows are declared here.
            models = [
              {
                id = "v3x-t/embeddinggemma-2";
                api = "openai-embeddings";
              }
              {
                id = "v3x-m/qwen3-embedding-0.6b";
                api = "openai-embeddings";
              }
              {
                id = "v3x-t/piper";
                api = "openai-speech";
              }
              {
                id = "v3x-t/qwen3-tts";
                api = "openai-speech";
              }
              {
                # The LiteLLM pass-through to llama-swap's clef-flash, outside its model list.
                id = "clef-flash";
                api = "typesafe";
                baseUrl = "https://${services.inference.name}";
              }
            ];
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
            openai: 3
            anthropic: 3
            moonshot: 3
            meta: 3
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
        generate_image:
          enabled: true
        features:
          unexpectedStopDetection: smart
        memory:
          backend: mnemopi
        # MNEMOPI_EMBEDDING_API_KEY and MNEMOPI_EMBEDDING_DIM come from the
        # sandbox environment: these settings take neither a command nor the dimension.
        mnemopi:
          scoping: per-project-tagged
          embeddingModel: v3x-t/embeddinggemma-2
          embeddingApiUrl: https://${services.inference.name}/v1
      '';

      # A profile is a role map, and may pin subagent models through
      # `agentModelOverrides` and add `settings` to its overlay. A fresh session
      # starts on the profile's default model; a resumed one keeps the model it
      # recorded, which is also how `agent` finds the profile that owns a
      # session. The toolsets extension records the session's toolsets the same way.
      profile = entry:
        entry
        // {
          command = [
            "omp"
            "--config"
            "${settings}"
            "--config"
            "${pkgs.writeText "omp-roles-${entry.name}.yml" (builtins.toJSON (lib.recursiveUpdate ({modelRoles = {inherit vision web judge memory;} // entry.modelRoles;}
                    // lib.optionalAttrs (entry ? agentModelOverrides) {task.agentModelOverrides = entry.agentModelOverrides;}) (entry.settings or {})))}"
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
      vision = preferences.anthropic_opus;
      # Our SearXNG first, then the session model's own hosted search.
      web = "web/searxng";
      # A decision model: native judgments for `find`, stop detection and TTSR.
      judge = "v3x-inference/clef-flash";
      # Mnemopi's fact extraction; the `tiny` fallback is too small for it.
      memory = preferences.openai_luna;
    in {
      glyph = "󰚩";
      color = "189;147;249";
      blurb = "Oh My Pi";
      logo = ../../../../assets/icons/omp.png;
      package = inputs.omp.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        patches = (old.patches or []) ++ [./discovery-owned-by.patch ./find-small-judge.patch];
      });
      inherit models mcp;
      profiles = map profile [
        {
          name = "gpt";
          glyph = "";
          color = "16;163;127";
          blurb = "OpenAI";
          logo = ../../../../assets/icons/openai.png;
          modelRoles = {
            default = preferences.openai_sol;
            inherit tiny;
            smol = preferences.openai_luna;
            slow = preferences.openai_astra;
          };
        }
        {
          name = "claude";
          glyph = "󰦣";
          color = "217;119;87";
          blurb = "Anthropic";
          logo = ../../../../assets/icons/claude.png;
          modelRoles = {
            default = preferences.anthropic_opus;
            inherit tiny;
            smol = preferences.anthropic_opus;
            slow = preferences.anthropic_fable;
          };
          agentModelOverrides.sonic = preferences.anthropic_haiku;
        }
        {
          name = "kimi";
          glyph = "";
          color = "248;248;242";
          blurb = "Moonshot";
          logo = ../../../../assets/icons/kimi.png;
          modelRoles = {
            default = "moonshot/kimi-k3-256k";
            inherit tiny;
            smol = "moonshot/kimi-k3-256k";
            slow = "moonshot/kimi-k3-256k";
          };
        }
        {
          name = "meta";
          glyph = "∞";
          color = "0;129;251";
          blurb = "Meta";
          logo = ../../../../assets/icons/meta.png;
          modelRoles = {
            default = "meta/muse-wonder-1.0";
            inherit tiny;
            smol = "meta/muse-spark-1.3";
            slow = "meta/muse-wonder-1.0";
          };
        }
        {
          name = "local";
          glyph = "";
          color = "80;250;123";
          blurb = "v3x-inference";
          logo = ../../../../assets/icons/local.png;
          modelRoles = {
            default = "v3x-inference/v3x-m/qwen3.8-27b";
            inherit tiny;
            smol = "v3x-inference/v3x-t/qwen3.6-35b-a3b";
            slow = "v3x-inference/v3x-m/qwen3.8-27b";
            # On the other host, so it does not swap clef-flash off teapot's GPU.
            memory = "v3x-inference/v3x-m/qwen3.6-35b-a3b";
            # No local model takes images; this makes image questions fail instead of leaving.
            vision = "@default";
          };
          # No automatic call leaves our hosts. With the gateway providers off, a
          # subagent pinned to a cloud model fails, so those run on local roles.
          # Image generation and describing pasted images need cloud models. A
          # per-project bank keeps memories out of the global bank that cloud
          # sessions recall.
          agentModelOverrides =
            lib.mapAttrs' (name: _: lib.nameValuePair "${name}-reviewer" "@slow") pinned
            // {comment-sicko = "@smol";};
          settings = {
            disabledProviders = ["openai" "anthropic" "moonshot" "meta"];
            generate_image.enabled = false;
            images.describeForTextModels = false;
            mnemopi.scoping = "per-project";
          };
        }
        {
          name = "openrouter";
          glyph = "";
          color = "148;163;184";
          blurb = "OpenRouter";
          logo = ../../../../assets/icons/openrouter.png;
          # `default` is deliberately absent: the picked OpenRouter model
          # arrives as --model, so a stale fallback here could silently win
          # instead.
          modelRoles = {
            inherit tiny;
            smol = preferences.openai_luna;
            slow = preferences.openai_astra;
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
