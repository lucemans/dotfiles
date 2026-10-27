{
  teapotModels,
  mediabusModels,
  ...
}: let
  inherit (import ../../../network/services.nix) services;
in {
  flake.nixosModules.litellm = {
    inputs,
    config,
    pkgs,
    lib,
    ...
  }: let
    backends = {
      v3x-t = {
        upstream = services.llamaTeapot.upstream;
        models = teapotModels;
      };
      v3x-m = {
        upstream = services.llamaMediabus.upstream;
        models = mediabusModels;
      };
    };

    localModels = lib.concatLists (lib.mapAttrsToList (prefix: backend:
      lib.mapAttrsToList (name: model: let
        metadata = model.litellm;
        decision = metadata.model_info.mode == "decisions";
      in
        metadata
        // {
          model_name = metadata.model_name or "${prefix}/${name}";
          litellm_params =
            {
              model = "${
                if decision
                then "hosted_vllm"
                else "openai"
              }/${name}";
              api_base = "http://${backend.upstream}/${
                if decision
                then "upstream/${name}"
                else "v1"
              }";
            }
            // lib.optionalAttrs (!decision) {api_key = "local";}
            // metadata.litellm_params or {};
        })
      (lib.filterAttrs (_: model: model ? litellm) backend.models))
    backends);

    openrouterModels = lib.mapAttrsToList (name: model:
      model
      // {
        model_name = name;
        litellm_params =
          {
            model = "openrouter/${lib.removePrefix "openrouter/" name}";
          }
          // model.litellm_params or {};
      })
    (import ../models/openrouter.nix);

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
        model_list = let
          models =
            localModels
            ++ [
              {
                litellm_params = {
                  api_base = "http://127.0.0.1:8083/v1";
                  api_key = "local";
                  model = "openai/piper";
                };
                model_info = {
                  health_check_voice = "glados-original";
                  mode = "audio_speech";
                };
                model_name = "v3x-t/piper";
              }
              {
                litellm_params = {
                  api_base = "http://127.0.0.1:8084/v1";
                  api_key = "local";
                  model = "openai/qwen3-tts";
                };
                model_info = {
                  health_check_voice = "glados";
                  mode = "audio_speech";
                };
                model_name = "v3x-t/qwen3-tts";
              }
              {
                litellm_params = {
                  api_base = "https://zeroparams.itdata.nu/v1";
                  api_key = "os.environ/ZEROPARAMS_API_KEY";
                  model = "openai/jonatan";
                };
                model_info = {
                  mode = "chat";
                };
                model_name = "zeroparams/jonatan";
              }
            ]
            ++ openrouterModels;
          names = map (model: model.model_name) models;
        in
          assert lib.assertMsg (lib.length names == lib.length (lib.unique names)) "LiteLLM public model names must be unique"; models;
        router_settings = {
          routing_strategy = "simple-shuffle";
          num_retries = 1;
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
