{
  flake.nixosModules.litellm = {
    inputs,
    config,
    pkgs,
    lib,
    ...
  }: let
    prisma-engines = inputs.prisma-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.prisma-engines;
    prisma = inputs.prisma-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.prisma;
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
      host = config.v3x.address;
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
            model_info = {
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/qwen3.6-35b-a3b";
            litellm_params = {
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/qwen3.6-35b-a3b";
              api_key = "local";
            };
            model_info = {
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/gpt-oss-20b";
            litellm_params = {
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/gpt-oss-20b";
              api_key = "local";
            };
            model_info = {
              input_cost_per_token = 0.00000018;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/qwen3-coder-30b-a3b";
            litellm_params = {
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/qwen3-coder-30b-a3b";
              api_key = "local";
            };
            model_info = {
              input_cost_per_token = 0.00000020;
              output_cost_per_token = 0.00000020;
            };
          }
          {
            model_name = "v3x-m/sweep-next-edit-v2-7b";
            litellm_params = {
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/sweep-next-edit-v2-7b";
              api_key = "local";
            };
            model_info = {
              input_cost_per_token = 0.00000002;
              output_cost_per_token = 0.00000002;
            };
          }
          {
            model_name = "v3x-m/qwen3.8-27b";
            litellm_params = {
              api_base = "https://ollama.v3x.sh/v1";
              model = "openai/qwen3.8-27b";
              api_key = "local";
            };
            model_info = {
              input_cost_per_token = 0.00000002;
              output_cost_per_token = 0.00000002;
            };
          }
          {
            model_name = "openai/gpt-5.6-luna";
            litellm_params.model = "openrouter/openai/gpt-5.6-luna";
            model_info.base_model = "gpt-5.6-luna";
          }
          {
            model_name = "z-ai/glm-5.3-flash";
            model_info.base_model = "z-ai/glm-5.3-flash";
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
      # host binds a tunnel address that does not exist until wg0 is up.
      after = ["postgresql.service" "wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
      path = [pkgs.openssl];
      # serviceConfig = {
      # TimeoutStartSec = "2min";
      # };
    };

    nixpkgs.overlays = [
      (final: prev: {
        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (pythonPackages: super: {
              langfuse = super.langfuse.overridePythonAttrs (old: {
                pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["wrapt"];
              });
              litellm = let
                expression = pythonPackages.buildPythonPackage rec {
                  pname = "expression";
                  version = "5.6.0";
                  pyproject = true;
                  src = pythonPackages.fetchPypi {
                    inherit pname version;
                    hash = "sha256-RU9v4Tg0cZSkPH+HjZWO/puEucx3DkYgEMelLhgFgGU=";
                  };
                  build-system = [pythonPackages.poetry-core];
                  dependencies = [pythonPackages.typing-extensions];
                  pythonImportsCheck = ["expression"];
                };
                proxyExtras = pythonPackages.buildPythonPackage {
                  pname = "litellm-proxy-extras";
                  version = "0.4.84";
                  pyproject = true;
                  src = super.litellm.src;
                  sourceRoot = "source/litellm-proxy-extras";
                  postPatch = ''
                    rm -rf dist
                    substituteInPlace pyproject.toml \
                      --replace-fail "uv_build==0.11.8" "uv_build"
                  '';
                  build-system = [pythonPackages.uv-build];
                  pythonImportsCheck = ["litellm_proxy_extras"];
                };
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
                  dependencies = (old.dependencies or []) ++ [expression proxyExtras];
                  makeWrapperArgs =
                    (old.makeWrapperArgs or [])
                    ++ [
                      "--prefix PATH : ${lib.makeBinPath [prisma]}"
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
      })
    ];
  };
}
