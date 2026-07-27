{
  flake.nixosModules.teapotLlm = {
    config,
    lib,
    pkgs,
    inputs,
    ...
  }: let
    # CUDA build: proprietary nvidia driver loads since 2026-07-27 (after
    # reboot); CUDA prefill is much faster than the old Vulkan/NVK path.
    llama-cpp = pkgs.llama-cpp.override { cudaSupport = true; };
    llama-server = lib.getExe' llama-cpp "llama-server";
    # Must match the engines commit baked into the prisma-client-py override
    # (hosts/teapot/configuration.nix) and the prisma CLI on litellm's PATH.
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

    # Split-horizon override: public DNS points ollama.v3x.sh at Cloudflare,
    # whose route doesn't reach mediabus from here (and CF kills idle
    # connections at ~100s anyway). Pin it to mediabus's LAN IP so litellm
    # talks straight to its Traefik (valid TLS cert, same hostname).
    networking.hosts."10.90.0.11" = ["ollama.v3x.sh"];

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
    sops.secrets.teapot_litellm_openrouter_key = {
      mode = "0400";
    };

    sops.templates.teapot_litellm_env = {
      mode = "0400";
      content = ''
        LITELLM_MASTER_KEY=${config.sops.placeholder.teapot_litellm_master_key}
        LITELLM_SALT_KEY=${config.sops.placeholder.teapot_litellm_salt_key}
        OPENROUTER_API_KEY=${config.sops.placeholder.teapot_litellm_openrouter_key}
        DATABASE_URL=postgresql://litellm@127.0.0.1/litellm
      '';
    };

    services.llama-swap = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 8081;

      settings = {
        # Cold load of the 23G MoE GGUF takes a while on first request.
        healthCheckTimeout = 300;

        models = {
          # MoE: attention/dense layers + KV on the GPU, experts mostly in
          # system RAM. --n-cpu-moe tuned via llama-fit-params: 13 of 41
          # expert layers fit in VRAM at 128k ctx with q8_0 KV cache.
          # Generation stays RAM-bandwidth-bound (~55 GB/s).
          # Served ctx (131072) must match hermes settings.model.context_length.
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
            # llama-server has one slot (--parallel 1) but queues excess
            # requests itself. A limit of 1 here made llama-swap 429 the
            # second concurrent request (hermes turn + compression call),
            # which surfaced in hermes as a bogus "rate limited" error.
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
        # prisma-client-py cannot download engine binaries on NixOS
        # (no "linux-nixos" target upstream); point it at ours instead.
        PRISMA_QUERY_ENGINE_BINARY = lib.getExe' prisma-engines "query-engine";
        PRISMA_SCHEMA_ENGINE_BINARY = lib.getExe' prisma-engines "schema-engine";
      };
      settings = {
        general_settings = {
          master_key = "os.environ/LITELLM_MASTER_KEY";
          database_url = "os.environ/DATABASE_URL";
        };
        model_list = [
          # "openai/" below is litellm's provider prefix for any
          # OpenAI-compatible endpoint (both are llama-swap), not OpenAI
          # itself. Clients only ever see the model_name.
          {
            model_name = "v3x-t/qwen3.6-35b-a3b";
            litellm_params = {
              model = "openai/qwen3.6-35b-a3b";
              api_base = "http://127.0.0.1:8081/v1";
              api_key = "local";
            };
          }
          {
            model_name = "v3x-m/qwen3.6-35b-a3b";
            litellm_params = {
              # mediabus llama-swap (2x RTX A4000) behind its Traefik.
              # ollama.v3x.sh is pinned to the LAN IP via networking.hosts
              # above — do NOT remove that pin, or this route goes through
              # Cloudflare and breaks.
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/qwen3.6-35b-a3b";
              api_key = "local";
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
          # Prefer mediabus (2x A4000, ~2x faster); fall back to the local
          # model if it's unreachable. Note teapot's model unloads after 15
          # min idle, so a failover request may eat a ~30s cold load.
          fallbacks = [
            {"v3x-m/qwen3.6-35b-a3b" = ["v3x-t/qwen3.6-35b-a3b"];}
          ];
        };
      };
    };

    systemd.services.litellm = {
      requires = ["postgresql.service"];
      after = ["postgresql.service"];
      # prisma-client-py shells out to `openssl version` during engine setup.
      path = [pkgs.openssl];
      serviceConfig = {
        TimeoutStartSec = "10min";
      };
    };
  };
}
