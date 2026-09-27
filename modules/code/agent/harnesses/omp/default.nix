{inputs, ...}: {
  flake.nixosModules.omp = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (import ../../../../network/services.nix) services;
  in {
    home-manager.users.luc.home.file.".omp/agent/themes/titanium-v3x.json".source = ./titanium-v3x.json;

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
            modelOverrides."claude-fable-5-1".thinking = {
              mode = "anthropic-adaptive";
              efforts = ["low" "medium" "high" "xhigh" "max"];
              supportsDisplay = true;
            };
            discovery.type = "openai-models-list";
            # Discovery lists these without their real context limits, so the
            # limits are stated here until the gateway reports them.
            models =
              map (id: {
                inherit id;
                contextWindow = 1050000;
                maxTokens = 128000;
              }) ["gpt-5.6-luna" "gpt-5.6-terra" "gpt-5.6-sol" "gpt-6-luna" "gpt-6-sol" "gpt-6-astra" "claude-opus-5-5"]
              ++ [
                {
                  id = "kimi-k3-256k";
                  contextWindow = 256000;
                  maxTokens = 128000;
                }
              ];
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
          webSearchOrder: [searxng]
          webSearchExclude:
            - perplexity
            - gemini
            - anthropic
            - codex
            - xai
            - zai
            - exa
            - tinyfish
            - jina
            - kagi
            - tavily
            - firecrawl
            - brave
            - kimi
            - parallel
            - synthetic
            - ollama
            - startpage
            - duckduckgo
            - ecosia
            - google
            - mojeek
            - public
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
            "${pkgs.writeText "omp-roles-${entry.name}.yml" (builtins.toJSON {inherit (entry) modelRoles;})}"
            "--extension"
            "${./agent-toolsets.ts}"
          ];
          # A profile with a catalog leaves --model to the picked entry.
          start = lib.optionals (!(entry ? catalog)) ["--model" "@default"];
        };

      tiny = "v3x-inference/v3x-m/nex-n2.5-mini";
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
            default = "anthropic/gpt-6-sol";
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
