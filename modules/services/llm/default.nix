{
  flake.nixosModules.teapotLlm = {
    config,
    lib,
    pkgs,
    inputs,
    ...
  }: let
    llama-cpp = pkgs.llama-cpp.override {cudaSupport = true;};
    llama-server = lib.getExe' llama-cpp "llama-server";
    prisma-engines = inputs.prisma-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.prisma-engines;
  in {
    nixpkgs.config.allowUnfree = true;

    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    networking.firewall.allowedTCPPorts = [
      4000
    ];

    networking.hosts."10.90.0.11" = ["ollama.v3x.sh"];

    systemd.tmpfiles.rules = [
      "d /var/lib/llama-models 0755 root root -"
    ];

    environment.systemPackages = with pkgs; [
      llmfit
    ];

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
        DATABASE_URL=postgresql://litellm@127.0.0.1/litellm
      '';
    };

    services.llama-swap = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 8081;

      settings = {
        healthCheckTimeout = 300;

        models = {
          "qwen3.6-35b-a3b" = {
            cmd = ''
              ${llama-server} \
                --port ${"\${PORT}"} \
                --model /var/lib/llama-models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf \
                --alias qwen3.6-35b-a3b \
                --ctx-size 131072 \
                --n-gpu-layers 99 \
                --n-cpu-moe 28 \
                --flash-attn on \
                --cache-type-k q8_0 \
                --cache-type-v q8_0 \
                --jinja \
                --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 \
                --parallel 1 \
                --no-webui
            '';
            ttl = 900;
            concurrencyLimit = 10;
          };
        };

        groups.local-gpu = {
          swap = true;
          exclusive = true;
          members = [
            "qwen3.6-35b-a3b"
          ];
        };
      };
    };

    services.litellm = {
      enable = true;
      host = "0.0.0.0";
      port = 4000;
      environmentFile = config.sops.templates.teapot_litellm_env.path;
      environment = {
        HOME = "/var/lib/litellm";
        PRISMA_QUERY_ENGINE_BINARY = lib.getExe' prisma-engines "query-engine";
        PRISMA_SCHEMA_ENGINE_BINARY = lib.getExe' prisma-engines "schema-engine";
      };
      settings = {
        general_settings = {
          master_key = "os.environ/LITELLM_MASTER_KEY";
          database_url = "os.environ/DATABASE_URL";
        };
        model_list = [
          {
            model_name = "v3x-t/qwen3.6-35b-a3b";
            litellm_params = {
              model = "openai/qwen3.6-35b-a3b";
              api_base = "http://127.0.0.1:8081/v1";
              api_key = "local";
            };
          }
          {
            model_name = "v3x-m/muse-glimmer-30b";
            litellm_params = {
              model = "openai/muse-glimmer-30b";
              api_base = "http://127.0.0.1:8081/v1";
              api_key = "local";
            };
          }
          {
            model_name = "v3x-m/qwen3.6-35b-a3b";
            litellm_params = {
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/qwen3.6-35b-a3b";
              api_key = "local";
            };
          }
          {
            model_name = "v3x-m/gpt-oss-20b";
            litellm_params = {
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/gpt-oss-20b";
              api_key = "local";
            };
          }
          {
            model_name = "v3x-m/qwen3-coder-30b-a3b";
            litellm_params = {
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/qwen3-coder-30b-a3b";
              api_key = "local";
            };
          }
          {
            model_name = "openai/gpt-5.6-luna";
            litellm_params.model = "openrouter/openai/gpt-5.6-luna";
            model_info.base_model = "gpt-5.6-luna";
          }
          {
            model_name = "zeroparams/jonatan";
            litellm_params = {
              api_base = "https://zeroparams.itdata.nu/v1";
              model = "openai/jonatan";
              api_key = "os.environ/ZEROPARAMS_API_KEY";
            };
          }
          {
            model_name = "*";
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
      after = ["postgresql.service"];
      path = [pkgs.openssl];
      serviceConfig = {
        TimeoutStartSec = "10min";
      };
    };
  };
}
