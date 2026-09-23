{inputs, ...}: {
  flake.nixosModules.omp = {
    config,
    lib,
    pkgs,
    self,
    ...
  }: let
    inherit (import ../../network/services.nix) services;
  in {
    home-manager.users.luc.home.file.".omp/agent/themes/titanium-v3x.json".source = ./titanium-v3x.json;

    sops.secrets.v3x_error_menu_token.owner = "luc";

    agentRuntime.harnesses.omp = let
      mcp = pkgs.writeText "omp-mcp.json" (builtins.toJSON {
        mcpServers =
          self.mcp.omp
          // {
            error_menu = {
              type = "http";
              url = "https://error.menu/mcp";
              headers.Authorization = "!${pkgs.coreutils}/bin/printf 'Bearer %s' \"$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.sops.secrets.v3x_error_menu_token.path})\"";
              enabled = true;
              timeout = 30000;
            };
            sdrangel = {
              type = "http";
              url = "http://127.0.0.1:8092";
              enabled = true;
              timeout = 30000;
            };
          };
        enabledServers = ["playwright" "dapp_wallet"];
      });
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
        # Use the shared `playwright` MCP server (see enabledServers) for the
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
      # also how `agent` finds the profile that owns a session.
      profile = entry:
        entry
        // {
          command = ["omp" "--config" "${settings}" "--config" "${pkgs.writeText "omp-roles-${entry.name}.yml" (builtins.toJSON {inherit (entry) modelRoles;})}"];
          # A profile with a catalog leaves --model to the picked entry.
          start = lib.optionals (!(entry ? catalog)) ["--model" "@default"];
        };

      tiny = "v3x-inference/v3x-m/nex-n2.5-mini";
    in {
      glyph = "󰚩";
      color = "189;147;249";
      blurb = "Oh My Pi";
      logo = ../agent/icons/omp.png;
      package = inputs.omp.packages.${pkgs.stdenv.hostPlatform.system}.default;
      inherit models mcp;
      profiles = map profile [
        {
          name = "gpt";
          glyph = "";
          color = "16;163;127";
          blurb = "OpenAI";
          logo = ../agent/icons/openai.png;
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
          logo = ../agent/icons/claude.png;
          modelRoles = {
            default = "anthropic/claude-opus-5-5";
            inherit tiny;
            smol = "anthropic/claude-opus-5";
            slow = "anthropic/claude-fable-5-1";
          };
        }
        {
          name = "kimi";
          glyph = "";
          color = "248;248;242";
          blurb = "Moonshot";
          logo = ../agent/icons/kimi.png;
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
          logo = ../agent/icons/local.png;
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
          logo = ../agent/icons/openrouter.png;
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
