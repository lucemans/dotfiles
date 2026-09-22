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

    agentRuntime.omp = {
      package = inputs.omp.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
      models = pkgs.writeText "omp-models.yml" ''
        providers:
          anthropic:
            baseUrl: https://${services.agent.name}
            api: anthropic-messages
            apiKey: "!${pkgs.coreutils}/bin/printenv ANTHROPIC_API_KEY"
            modelOverrides:
              claude-fable-5-1:
                thinking:
                  mode: anthropic-adaptive
                  efforts: [low, medium, high, xhigh, max]
                  supportsDisplay: true
            discovery:
              type: openai-models-list
            models:
              - id: gpt-5.6-luna
                contextWindow: 1050000
                maxTokens: 128000
              - id: gpt-5.6-terra
                contextWindow: 1050000
                maxTokens: 128000
              - id: gpt-5.6-sol
                contextWindow: 1050000
                maxTokens: 128000
              - id: gpt-6-luna
                contextWindow: 1050000
                maxTokens: 128000
              - id: gpt-6-sol
                contextWindow: 1050000
                maxTokens: 128000
              - id: gpt-6-astra
                contextWindow: 1050000
                maxTokens: 128000
              - id: kimi-k3-256k
                contextWindow: 256000
                maxTokens: 128000
          v3x-inference:
            baseUrl: https://${services.inference.name}/v1
            api: openai-completions
            apiKey: "!${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.sops.secrets.v3x_inference_token.path}"
            authHeader: true
            discovery:
              type: litellm
      '';
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
      roles = {
        gpt = pkgs.writeText "omp-roles-gpt.yml" ''
          modelRoles:
            default: anthropic/gpt-5.6-terra
            tiny: v3x-inference/v3x-m/nex-n2.5-mini
            smol: anthropic/gpt-5.6-luna
            slow: anthropic/gpt-6-astra
        '';
        claude = pkgs.writeText "omp-roles-claude.yml" ''
          modelRoles:
            default: anthropic/claude-opus-5
            tiny: v3x-inference/v3x-m/nex-n2.5-mini
            smol: anthropic/claude-sonnet-5
            slow: anthropic/claude-fable-5-1
        '';
        kimi = pkgs.writeText "omp-roles-kimi.yml" ''
          modelRoles:
            default: anthropic/kimi-k3-256k
            tiny: v3x-inference/v3x-m/nex-n2.5-mini
            smol: anthropic/kimi-k3-256k
            slow: anthropic/kimi-k3-256k
        '';
        # `default` is deliberately absent: the picked OpenRouter model arrives
        # as --model, so a stale fallback here could silently win instead.
        openrouter = pkgs.writeText "omp-roles-openrouter.yml" ''
          modelRoles:
            tiny: v3x-inference/v3x-m/nex-n2.5-mini
            smol: anthropic/gpt-5.6-luna
            slow: anthropic/gpt-6-astra
        '';
        local = pkgs.writeText "omp-roles-local.yml" ''
          modelRoles:
            default: v3x-inference/v3x-m/qwen3.8-27b
            tiny: v3x-inference/v3x-m/nex-n2.5-mini
            smol: v3x-inference/v3x-t/qwen3.6-35b-a3b
            slow: v3x-inference/v3x-m/qwen3.8-27b
        '';
      };
    };
  };
}
