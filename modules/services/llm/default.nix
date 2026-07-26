{
  flake.nixosModules.teapotLlm = {
    config,
    lib,
    pkgs,
    ...
  }: let
    llama-cpp = pkgs.llama-cpp-vulkan;
    llama-server = lib.getExe' llama-cpp "llama-server";
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

    # Model files are mutable runtime data, never Nix store paths.
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

    sops.templates.teapot_litellm_env = {
      mode = "0400";
      content = ''
        LITELLM_MASTER_KEY=${config.sops.placeholder.teapot_litellm_master_key}
        LITELLM_SALT_KEY=${config.sops.placeholder.teapot_litellm_salt_key}
        DATABASE_URL=postgresql://litellm@127.0.0.1/litellm
      '';
    };

    services.llama-swap = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 8081;

      settings = {
        healthCheckTimeout = 120;

        models = {
          qwen3-8b = {
            cmd = ''
              ${llama-server} \
                --port ${"\${PORT}"} \
                --model /var/lib/llama-models/Qwen3-8B-Q4_K_M.gguf \
                --alias qwen3-8b \
                --ctx-size 8192 \
                --n-gpu-layers 99 \
                --parallel 1 \
                --flash-attn on \
                --no-webui
            '';
            ttl = 900;
            concurrencyLimit = 1;
          };

          # Add a second model here. It will replace qwen3-8b, not run beside it.
          # "qwen3-14b" = {
          #   cmd = ''
          #     ${llama-server} \
          #       --port ${"\${PORT}"} \
          #       --model /var/lib/llama-models/Qwen3-14B-Q4_K_M.gguf \
          #       --alias qwen3-14b \
          #       --ctx-size 4096 \
          #       --n-gpu-layers 99 \
          #       --parallel 1 \
          #       --flash-attn on \
          #       --no-webui
          #   '';
          #   ttl = 900;
          #   concurrencyLimit = 1;
          # };
        };

        groups.local-gpu = {
          swap = true;
          exclusive = true;
          members = [
            "qwen3-8b"
            # "qwen3-14b"
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
      };
      settings = {
        general_settings = {
          master_key = "os.environ/LITELLM_MASTER_KEY";
          database_url = "os.environ/DATABASE_URL";
        };
        model_list = [
          {
            model_name = "local/qwen3-8b";
            litellm_params = {
              model = "openai/qwen3-8b";
              api_base = "http://127.0.0.1:8081/v1";
              api_key = "local";
            };
          }
        ];
        router_settings = {
          routing_strategy = "simple-shuffle";
          num_retries = 1;
        };
      };
    };

    systemd.services.litellm = {
      requires = ["postgresql.service"];
      after = ["postgresql.service"];
      serviceConfig = {
        TimeoutStartSec = "10min";
      };
    };
  };
}
