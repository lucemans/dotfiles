{
  flake.nixosModules.litellm = {
    config,
    pkgs,
    ...
  }: {
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
        ZEROPARAMS_API_KEY=${config.sops.placeholder.teapot_litellm_zeroparams_key}
        DATABASE_URL=postgresql://litellm@127.0.0.1/litellm
      '';
    };

    services.litellm = {
      enable = true;
      host = "0.0.0.0";
      port = 4000;
      environmentFile = config.sops.templates.teapot_litellm_env.path;
      environment = {
        HOME = "/var/lib/litellm";
        # PRISMA_QUERY_ENGINE_BINARY = lib.getExe' prisma-engines "query-engine";
        # PRISMA_SCHEMA_ENGINE_BINARY = lib.getExe' prisma-engines "schema-engine";
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
