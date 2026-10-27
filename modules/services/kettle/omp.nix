# OMP for Kettle Runner: the providers and the pinned reviewers. Runs use
# Kettle Code's own OMP (18.11), so this follows modules/agent/harnesses/omp
# except where 18.11 differs: the gateway's OpenAI models go over
# `openai-responses`, and the reviewers read 18.11's bundled prompt.
{
  inputs,
  lib,
  pkgs,
  # Host path of the v3x-inference key, which OMP reads at each request.
  inferenceToken,
}: let
  inherit (import ../../network/services.nix) services;

  preferences = import ../../agent/configs/model-preferences.nix;

  pinned = {
    kimi = "moonshot/kimi-k3-256k";
    muse-wonder = "meta/muse-wonder-1.0";
    muse-spark = "meta/muse-spark-1.3";
    opus = preferences.anthropic_opus;
    sol = preferences.openai_sol;
  };
  prompts = "${inputs.kettle-code.inputs.oh-my-pi}/packages/coding-agent/src/prompts/agents";
  reviewer = builtins.readFile "${prompts}/reviewer.md";
  reviewerFields = [
    "name: reviewer\n"
    "description: \"Code review specialist for quality/security analysis\"\n"
    "model: \"@slow\"\n"
  ];

  gateway = {
    baseUrl = "https://${services.agent.name}";
    api = "anthropic-messages";
    apiKey = "!${pkgs.coreutils}/bin/printenv ANTHROPIC_API_KEY";
    auth = "apiKey";
  };
in {
  # One `<name>-reviewer.md` per pinned model, each the bundled reviewer prompt
  # with only the model changed.
  reviewers = lib.mapAttrsToList (name: model:
    pkgs.writeText "${name}-reviewer.md" (assert lib.assertMsg (lib.all (field: lib.hasInfix field reviewer) reviewerFields)
      "omp: the bundled reviewer.md frontmatter changed, update reviewerFields";
        builtins.replaceStrings reviewerFields [
          "name: ${name}-reviewer\n"
          "description: ${builtins.toJSON "Code review specialist for quality/security analysis on ${model}"}\n"
          "model: ${builtins.toJSON model}\n"
        ]
        reviewer))
  pinned;

  models = pkgs.writeText "omp-models.yml" (builtins.toJSON {
    providers = {
      openai =
        gateway
        // {
          api = "openai-responses";
          baseUrl = "${gateway.baseUrl}/v1";
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
        apiKey = "!${pkgs.coreutils}/bin/cat ${lib.escapeShellArg inferenceToken}";
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
}
