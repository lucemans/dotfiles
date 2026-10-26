_: let
  inherit (import ../../../network/services.nix) services;
in {
  flake.nixosModules.litellm = {
    inputs,
    config,
    pkgs,
    lib,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    prisma-engines = inputs.prisma-nixpkgs.legacyPackages.${system}.prisma-engines;
    prisma = inputs.prisma-nixpkgs.legacyPackages.${system}.prisma;
    # litellm comes from a pinned newer nixpkgs: the decision routes need
    # >= 1.104.2 and nixos-unstable lags behind. Its closure is self-contained.
    litellmPkgs = inputs.nixpkgs-litellm.legacyPackages.${system}.extend (_final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (pythonPackages: super: {
            litellm = let
              prismaPython = super.prisma.overridePythonAttrs (old: {
                postPatch =
                  (old.postPatch or "")
                  + ''
                    substituteInPlace src/prisma/_config.py \
                      --replace-fail "default='5.17.0'" "default='5.18.0'" \
                      --replace-fail "default='393aa359c9ad4a4bb28630fb5613f9c281cde053'" "default='4c784e32044a8a016d99474bd02a3b6123742169'"
                  '';
                postInstall =
                  (old.postInstall or "")
                  + ''
                    schema="$TMPDIR/litellm-schema.prisma"
                    substitute ${super.litellm.src}/schema.prisma "$schema" \
                      --replace-fail '  provider = "prisma-client-py"' "  provider = \"prisma-client-py\"
                      output = \"$out/${pythonPackages.python.sitePackages}/prisma\""

                    export PYTHONPATH="$out/${pythonPackages.python.sitePackages}:$PYTHONPATH"
                    PATH="$out/bin:$PATH" ${lib.getExe' prisma "prisma"} generate --schema="$schema"
                  '';
                pythonImportsCheck = (old.pythonImportsCheck or []) ++ ["prisma.client"];
              });
            in
              (super.litellm.override {prisma = prismaPython;}).overridePythonAttrs (old: {
                makeWrapperArgs =
                  (old.makeWrapperArgs or [])
                  ++ [
                    "--prefix"
                    "PATH"
                    ":"
                    (lib.makeBinPath [prisma])
                  ];
                pythonImportsCheck =
                  (old.pythonImportsCheck or [])
                  ++ [
                    "litellm_proxy_extras"
                    "litellm.proxy._experimental.mcp_server.outbound_credentials.types"
                    "prisma.client"
                  ];
              });
          })
        ];
    });
  in {
    sops.secrets.teapot_litellm_master_key = {
      mode = "0400";
    };
    sops.secrets.teapot_litellm_salt_key = {
      mode = "0400";
    };
    sops.secrets.teapot_litellm_openrouter_key = {
      mode = "0400";
    };
    sops.secrets.teapot_litellm_zeroparams_key = {
      mode = "0400";
    };

    sops.templates.teapot_litellm_env = {
      mode = "0400";
      content = ''
        LITELLM_MASTER_KEY=${config.sops.placeholder.teapot_litellm_master_key}
        LITELLM_SALT_KEY=${config.sops.placeholder.teapot_litellm_salt_key}
        OPENROUTER_API_KEY=${config.sops.placeholder.teapot_litellm_openrouter_key}
        ZEROPARAMS_API_KEY=${config.sops.placeholder.teapot_litellm_zeroparams_key}
        GENERIC_CLIENT_SECRET=${config.sops.placeholder.teapot_litellm_oauth2_secret}
        DATABASE_URL=postgresql://litellm@127.0.0.1/litellm
      '';
    };

    services.postgresql = {
      enable = true;
      authentication = ''
        host litellm litellm 127.0.0.1/32 trust
      '';
      ensureDatabases = ["litellm"];
      ensureUsers = [
        {
          name = "litellm";
          ensureDBOwnership = true;
        }
      ];
    };

    services.litellm = {
      enable = true;
      package = litellmPkgs.litellm;
      host = config.v3x.address;
      port = 4000;
      environmentFile = config.sops.templates.teapot_litellm_env.path;
      environment = {
        HOME = "/var/lib/litellm";
        PRISMA_QUERY_ENGINE_BINARY = lib.getExe' prisma-engines "query-engine";
        PRISMA_SCHEMA_ENGINE_BINARY = lib.getExe' prisma-engines "schema-engine";
        # litellm derives the OAuth redirect uri from the address it is bound
        # to, which behind the proxy is not the address the browser used.
        PROXY_BASE_URL = "https://${services.inference.name}";
        GENERIC_CLIENT_ID = "litellm";
        GENERIC_AUTHORIZATION_ENDPOINT = "https://${services.auth.name}/ui/oauth2";
        GENERIC_TOKEN_ENDPOINT = "https://${services.auth.name}/oauth2/token";
        GENERIC_USERINFO_ENDPOINT = "https://${services.auth.name}/oauth2/openid/litellm/userinfo";
        # Kanidm rejects an authorization code flow without PKCE.
        GENERIC_CLIENT_USE_PKCE = "true";
      };
      settings = {
        general_settings = {
          master_key = "os.environ/LITELLM_MASTER_KEY";
          database_url = "os.environ/DATABASE_URL";
        };
        model_list = [
          {
            model_name = "v3x-m/qwen3-embedding-0.6b";
            litellm_params = {
              model = "openai/qwen3-embedding-0.6b";
              api_base = "http://10.90.0.11:11434/v1";
              api_key = "local";
            };
            model_info = {
              mode = "embedding";
              input_cost_per_token = 0.00000005;
              output_cost_per_token = 0.00000005;
            };
          }
          {
            model_name = "v3x-t/embeddinggemma-2";
            litellm_params = {
              model = "openai/embeddinggemma-2";
              api_base = "http://127.0.0.1:8081/v1";
              api_key = "local";
            };
            model_info = {
              mode = "embedding";
              input_cost_per_token = 0.00000005;
            };
          }
          {
            model_name = "v3x-t/qwen3.6-35b-a3b";
            litellm_params = {
              model = "openai/qwen3.6-35b-a3b";
              api_base = "http://127.0.0.1:8081/v1";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            # A decision model: llama-swap serves it on /v1/systemone only. The
            # hosted_vllm provider posts to <api_base>/v1/systemone.
            model_name = "clef-flash";
            litellm_params = {
              model = "hosted_vllm/clef-flash";
              api_base = "http://127.0.0.1:8081/upstream/clef-flash";
            };
            model_info.mode = "decisions";
          }
          {
            # A second judge lane: Perplexity's decider-flash speaks the same
            # System One API, reached through its llama-swap upstream.
            model_name = "pplx-decider-flash";
            litellm_params = {
              model = "hosted_vllm/pplx-decider-flash";
              api_base = "http://10.90.0.11:11434/upstream/pplx-decider-flash";
            };
            model_info.mode = "decisions";
          }
          {
            model_name = "v3x-t/piper";
            litellm_params = {
              model = "openai/piper";
              api_base = "http://127.0.0.1:8083/v1";
              api_key = "local";
            };
            model_info = {
              mode = "audio_speech";
              health_check_voice = "glados-original";
            };
          }
          {
            model_name = "v3x-t/qwen3-tts";
            litellm_params = {
              model = "openai/qwen3-tts";
              api_base = "http://127.0.0.1:8084/v1";
              api_key = "local";
            };
            model_info = {
              mode = "audio_speech";
              health_check_voice = "glados";
            };
          }
          {
            model_name = "v3x-m/qwen3.6-35b-a3b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/qwen3.6-35b-a3b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/gpt-oss-20b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/gpt-oss-20b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000018;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/qwen3-coder-30b-a3b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/qwen3-coder-30b-a3b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/zeta-2.1";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/zeta-2.1";
              api_key = "local";
            };
            model_info = {
              mode = "completion";
              input_cost_per_token = 0.00000002;
              output_cost_per_token = 0.00000002;
            };
          }
          {
            model_name = "v3x-m/sweep-next-edit-v2-7b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/sweep-next-edit-v2-7b";
              api_key = "local";
            };
            model_info = {
              mode = "completion";
              input_cost_per_token = 0.00000002;
              output_cost_per_token = 0.00000002;
            };
          }
          {
            model_name = "v3x-m/muse-glimmer-30b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/muse-glimmer-30b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/qwen3.8-27b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/qwen3.8-27b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/nex-n2.5-mini";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/nex-n2.5-mini";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000010;
              output_cost_per_token = 0.00000010;
            };
          }
          {
            model_name = "v3x-m/nex-n2.5-mini-uncensored";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/nex-n2.5-mini-uncensored";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000010;
              output_cost_per_token = 0.00000010;
            };
          }
          {
            model_name = "v3x-m/minicpm5-2b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/minicpm5-2b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000005;
              output_cost_per_token = 0.00000005;
            };
          }
          {
            model_name = "v3x-m/spark-x2.6-4b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/spark-x2.6-4b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000005;
              output_cost_per_token = 0.00000005;
            };
          }
          {
            model_name = "v3x-m/qwen3.8-flash-next";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/qwen3.8-flash-next";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-t/spark-x2.6-4b";
            litellm_params = {
              model = "openai/spark-x2.6-4b";
              api_base = "http://127.0.0.1:8081/v1";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000005;
              output_cost_per_token = 0.00000005;
            };
          }
          {
            model_name = "v3x-m/flint-1";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/flint-1";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/nanbeige4.3-33b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/nanbeige4.3-33b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/sage-a1.5";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/sage-a1.5";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/bonsai-2-27b";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/bonsai-2-27b";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000010;
              output_cost_per_token = 0.00000010;
            };
          }
          {
            model_name = "v3x-m/hemmingway-1";
            litellm_params = {
              api_base = "http://10.90.0.11:11434/v1";
              model = "openai/hemmingway-1";
              api_key = "local";
            };
            model_info = {
              mode = "chat";
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "openai/gpt-5.6-luna";
            litellm_params.model = "openrouter/openai/gpt-5.6-luna";
            model_info.base_model = "gpt-5.6-luna";
            model_info.mode = "chat";
          }
          {
            model_name = "openai/gpt-6-luna";
            litellm_params.model = "openrouter/openai/gpt-6-luna";
            model_info.base_model = "gpt-6-luna";
            model_info.mode = "chat";
          }
          {
            model_name = "openai/gpt-oss-120b";
            litellm_params.model = "openrouter/openai/gpt-oss-120b";
            model_info.base_model = "openai/gpt-oss-120b";
            model_info.mode = "chat";
          }
          {
            model_name = "z-ai/glm-5.3-flash";
            model_info.base_model = "z-ai/glm-5.3-flash";
            model_info.mode = "chat";
            litellm_params = {
              model = "openrouter/z-ai/glm-5.3-flash";
              provider = {
                order = [
                  "baseten"
                  "z-ai"
                ];
                allow_fallbacks = true;
              };
            };
          }
          {
            model_name = "zeroparams/jonatan";
            litellm_params = {
              api_base = "https://zeroparams.itdata.nu/v1";
              model = "openai/jonatan";
              api_key = "os.environ/ZEROPARAMS_API_KEY";
            };
            model_info.mode = "chat";
          }
          {
            model_name = "openrouter/deepseek/deepseek-v4.1-flash";
            model_info.base_model = "deepseek/deepseek-v4.1-flash";
            model_info.mode = "chat";
            model_info.supports_reasoning = true;
            litellm_params = {
              model = "openrouter/deepseek/deepseek-v4.1-flash";
              provider = {
                order = [
                  "deepinfra/fp8"
                  "baseten"
                ];
                ignore = ["baseten/fast"];
                allow_fallbacks = false;
              };
            };
          }
          {
            model_name = "openrouter/deepseek/deepseek-v4.1-flash-1017";
            model_info.base_model = "deepseek/deepseek-v4.1-flash-1017";
            model_info.mode = "chat";
            model_info.supports_reasoning = true;
            litellm_params = {
              model = "openrouter/deepseek/deepseek-v4.1-flash-1017";
              provider = {
                order = [
                  "deepinfra/fp8"
                  "relace"
                  "inference-net/fp8"
                  "cloudflare"
                  "together"
                ];
                allow_fallbacks = false;
              };
            };
          }
          {
            model_name = "openrouter/*";
            litellm_params.model = "openrouter/*";
          }
        ];
        router_settings = {
          routing_strategy = "simple-shuffle";
          num_retries = 1;
          fallbacks = [
            {"v3x-m/qwen3.6-35b-a3b" = ["v3x-t/qwen3.6-35b-a3b"];}
          ];
        };
      };
    };

    systemd.services.litellm = {
      requires = ["postgresql.service"];
      # host binds a tunnel address that does not exist until wg0 is up.
      after = ["postgresql.service" "wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
      path = [pkgs.openssl];
      # serviceConfig = {
      # TimeoutStartSec = "2min";
      # };
    };
  };
}
