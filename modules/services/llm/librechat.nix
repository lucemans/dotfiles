{...}: let
  inherit (import ../../network/topology.nix) containers;
  inherit (import ../../network/services.nix) services;
in {
  flake.nixosModules.librechat = {
    config,
    lib,
    pkgs,
    ...
  }: let
    port = 3080;
    ragPort = 8000;
    network = "librechat";
    stateDir = "/var/lib/librechat";

    # Pinned so the firewall rule below can name the bridge, and so the
    # subnet matches the one the proxy allows.
    bridge = "librechat0";

    inference = "${config.services.litellm.host}:${toString config.services.litellm.port}";

    searxServer = config.services.searx.settings.server;
    searx = "${searxServer.bind_address}:${toString searxServer.port}";

    # Ports on the hub that containers reach: the proxy, and the two services
    # they talk to directly.
    hubPorts = [
      "443"
      (toString config.services.litellm.port)
      (toString searxServer.port)
    ];

    # Pinned so the bind mounted data directories keep one owner across
    # rebuilds. The images expect to run as the directory owner.
    id = 2379;
    runAs = "${toString id}:${toString id}";

    docker = lib.getExe config.virtualisation.docker.package;

    containerNames = [
      "librechat"
      "librechat-mongodb"
      "librechat-meilisearch"
      "librechat-vectordb"
      "librechat-rag"
    ];

    onNetwork = ["--network=${network}"];

    # The wildcard passthrough is not a model anyone can pick from a list.
    models =
      lib.filter (name: name != "*")
      (map (model: model.model_name) config.services.litellm.settings.model_list);

    # Our instance disables most of what LibreChat asks for by default, and
    # SearXNG answers an unknown engine with fewer results rather than an error.
    searxEngines =
      lib.filter
      (engine:
        !(lib.any
          (entry: entry.name == engine && entry.disabled or false)
          config.services.searx.settings.engines))
      ["google" "startpage" "bing" "duckduckgo" "brave"];

    librechatConfig = (pkgs.formats.yaml {}).generate "librechat.yaml" {
      version = "1.3.15";
      cache = true;

      webSearch = {
        searchProvider = "searxng";
        # Checked against webSearchKeys, which rejects a literal value here and
        # then leaves the provider unconfigured. The address is passed in as
        # SEARXNG_INSTANCE_URL below.
        searxngInstanceUrl = "\${SEARXNG_INSTANCE_URL}";
        searxngSearchOptions.engines = searxEngines;

        # Keenable needs no key; every reranker does.
        scraperProvider = "keenable";
        rerankerType = "none";

        # The guard blocks private destinations at connect time, and our own
        # instance is one.
        allowedAddresses = [searx];
      };

      endpoints.custom = [
        {
          name = "v3x";
          apiKey = "\${LITELLM_KEY}";
          baseURL = "http://${inference}/v1";
          modelDisplayLabel = "v3x";
          titleConvo = true;
          titleModel = "current_model";

          models = {
            default = models;
            fetch = false;
          };
        }
      ];
    };
  in {
    users.users.librechat = {
      isSystemUser = true;
      group = "librechat";
      uid = id;
      home = stateDir;
    };

    users.groups.librechat.gid = id;

    sops.secrets = {
      teapot_librechat_creds_key.mode = "0400";
      teapot_librechat_creds_iv.mode = "0400";
      teapot_librechat_jwt_secret.mode = "0400";
      teapot_librechat_jwt_refresh_secret.mode = "0400";
      teapot_librechat_meili_key.mode = "0400";
      teapot_librechat_postgres_password.mode = "0400";
      teapot_librechat_openid_session_secret.mode = "0400";
      teapot_librechat_rag_openai_key.mode = "0400";
      teapot_librechat_litellm_key.mode = "0400";
    };

    sops.templates.teapot_librechat_env = {
      mode = "0400";
      content = ''
        CREDS_KEY=${config.sops.placeholder.teapot_librechat_creds_key}
        CREDS_IV=${config.sops.placeholder.teapot_librechat_creds_iv}
        JWT_SECRET=${config.sops.placeholder.teapot_librechat_jwt_secret}
        JWT_REFRESH_SECRET=${config.sops.placeholder.teapot_librechat_jwt_refresh_secret}
        MEILI_MASTER_KEY=${config.sops.placeholder.teapot_librechat_meili_key}
        OPENID_CLIENT_SECRET=${config.sops.placeholder.teapot_librechat_oauth2_secret}
        OPENID_SESSION_SECRET=${config.sops.placeholder.teapot_librechat_openid_session_secret}
        LITELLM_KEY=${config.sops.placeholder.teapot_librechat_litellm_key}
      '';
    };

    sops.templates.teapot_librechat_meili_env = {
      mode = "0400";
      content = ''
        MEILI_MASTER_KEY=${config.sops.placeholder.teapot_librechat_meili_key}
      '';
    };

    sops.templates.teapot_librechat_postgres_env = {
      mode = "0400";
      content = ''
        POSTGRES_PASSWORD=${config.sops.placeholder.teapot_librechat_postgres_password}
      '';
    };

    sops.templates.teapot_librechat_rag_env = {
      mode = "0400";
      content = ''
        RAG_OPENAI_API_KEY=${config.sops.placeholder.teapot_librechat_rag_openai_key}
      '';
    };

    # Container traffic to a tunnel address arrives on the bridge rather than
    # on wg0, so it misses the tunnel accept rule. litellm and searx are
    # reached directly; 443 reaches kanidm through the proxy, because kanidm
    # hands out discovery endpoints on its public origin.
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -i ${bridge} -s ${containers} \
        -d ${config.v3x.address} -p tcp \
        -m multiport --dports ${lib.concatStringsSep "," hubPorts} -j ACCEPT
    '';

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 librechat librechat -"
      "d ${stateDir}/data 0750 librechat librechat -"
      "d ${stateDir}/images 0750 librechat librechat -"
      "d ${stateDir}/logs 0750 librechat librechat -"
      "d ${stateDir}/meili 0750 librechat librechat -"
      "d ${stateDir}/mongo 0750 librechat librechat -"
      "d ${stateDir}/uploads 0750 librechat librechat -"
      # The postgres entrypoint chowns this to its own user on first start.
      "d ${stateDir}/pgdata 0700 root root -"
    ];

    virtualisation.oci-containers = {
      backend = "docker";

      containers = {
        librechat = {
          image = "registry.librechat.ai/danny-avila/librechat-dev:latest";
          user = runAs;
          dependsOn = ["librechat-mongodb" "librechat-rag"];

          # The tunnel names live in the host's /etc/hosts, which a container
          # does not inherit, and the host does not run the tunnel resolver.
          extraOptions = onNetwork ++ ["--add-host=${services.auth.name}:${config.v3x.address}"];
          ports = ["${config.v3x.address}:${toString port}:${toString port}"];
          environmentFiles = [config.sops.templates.teapot_librechat_env.path];

          environment = {
            HOST = "0.0.0.0";
            PORT = toString port;
            MONGO_URI = "mongodb://librechat-mongodb:27017/LibreChat";
            MEILI_HOST = "http://librechat-meilisearch:7700";
            SEARCH = "true";
            RAG_API_URL = "http://librechat-rag:${toString ragPort}";
            RAG_PORT = toString ragPort;
            DOMAIN_CLIENT = "https://${services.chat.name}";
            DOMAIN_SERVER = "https://${services.chat.name}";
            LIBRECHAT_TEMP_CREDENTIALS_PATH = "/app/data/.env.temp";
            SEARXNG_INSTANCE_URL = "http://${searx}";

            # Discovery appends the well-known path to this base url itself.
            OPENID_ISSUER = "https://${services.auth.name}/oauth2/openid/librechat";
            OPENID_CLIENT_ID = "librechat";
            OPENID_CALLBACK_URL = "/oauth/openid/callback";
            OPENID_SCOPE = "openid profile email";
            # Kanidm maps name from displayname and emits no given_name, so
            # the default chain falls through to the mail address.
            OPENID_NAME_CLAIM = "name";
            OPENID_BUTTON_LABEL = "Sign in with v3x";
            # Kanidm rejects an authorization code flow without PKCE.
            OPENID_USE_PKCE = "true";

            # Without this the scheduler refuses to arm and schedule writes
            # answer 503, because it cannot prove it is the only replica.
            SCHEDULES_SINGLE_PROCESS = "true";

            ALLOW_EMAIL_LOGIN = "false";
            ALLOW_REGISTRATION = "false";
            ALLOW_SOCIAL_LOGIN = "true";
            ALLOW_SOCIAL_REGISTRATION = "true";
          };

          volumes = [
            "${librechatConfig}:/app/librechat.yaml:ro"
            "${stateDir}/data:/app/data"
            "${stateDir}/images:/app/client/public/images"
            "${stateDir}/logs:/app/logs"
            "${stateDir}/uploads:/app/uploads"
          ];
        };

        librechat-mongodb = {
          image = "mongo:8.0.20";
          user = runAs;
          cmd = ["mongod" "--noauth"];
          extraOptions = onNetwork;
          volumes = ["${stateDir}/mongo:/data/db"];
        };

        librechat-meilisearch = {
          image = "getmeili/meilisearch:v1.35.1";
          user = runAs;
          extraOptions = onNetwork;
          environmentFiles = [config.sops.templates.teapot_librechat_meili_env.path];

          environment = {
            MEILI_HOST = "http://librechat-meilisearch:7700";
            MEILI_NO_ANALYTICS = "true";
          };

          volumes = ["${stateDir}/meili:/meili_data"];
        };

        librechat-vectordb = {
          image = "pgvector/pgvector:0.8.0-pg15-trixie";
          extraOptions = onNetwork;
          environmentFiles = [config.sops.templates.teapot_librechat_postgres_env.path];

          environment = {
            POSTGRES_DB = "librechat";
            POSTGRES_USER = "librechat";
          };

          volumes = ["${stateDir}/pgdata:/var/lib/postgresql/data"];
        };

        librechat-rag = {
          image = "registry.librechat.ai/danny-avila/librechat-rag-api-dev-lite:latest";
          dependsOn = ["librechat-vectordb"];
          extraOptions = onNetwork;

          environmentFiles = [
            config.sops.templates.teapot_librechat_postgres_env.path
            config.sops.templates.teapot_librechat_rag_env.path
          ];

          environment = {
            DB_HOST = "librechat-vectordb";
            DB_PORT = "5432";
            POSTGRES_DB = "librechat";
            POSTGRES_USER = "librechat";
            RAG_PORT = toString ragPort;

            EMBEDDINGS_PROVIDER = "openai";
            EMBEDDINGS_MODEL = "text-embedding-3-small";
            RAG_OPENAI_BASEURL = "http://${inference}/v1";
          };
        };
      };
    };

    systemd.services =
      lib.genAttrs (map (name: "docker-${name}") containerNames) (_: {
        after = ["librechat-network.service"];
        requires = ["librechat-network.service"];
      })
      // {
        librechat-network = {
          wantedBy = ["multi-user.target"];
          after = ["docker.service"];
          requires = ["docker.service"];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = ''
            ${docker} network inspect ${network} > /dev/null 2>&1 \
              || ${docker} network create \
                   --subnet ${containers} \
                   --opt com.docker.network.bridge.name=${bridge} \
                   ${network}
          '';
        };

        # ports binds a tunnel address that does not exist until wg0 is up.
        docker-librechat = {
          after = ["librechat-network.service" "wireguard-wg0.service"];
          requires = ["librechat-network.service"];
          wants = ["wireguard-wg0.service"];
        };
      };
  };
}
