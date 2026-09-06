{...}: let
  inherit (import ../../network/topology.nix) services;
in {
  flake.nixosModules.librechat = {
    config,
    lib,
    ...
  }: let
    port = 3080;
    ragPort = 8000;
    network = "librechat";
    stateDir = "/var/lib/librechat";

    # Pinned so the bind mounted data directories keep one owner across
    # rebuilds. The images expect to run as the directory owner.
    id = 2379;
    runAs = "${toString id}:${toString id}";

    docker = lib.getExe config.virtualisation.docker.package;

    containers = [
      "librechat"
      "librechat-mongodb"
      "librechat-meilisearch"
      "librechat-vectordb"
      "librechat-rag"
    ];

    onNetwork = ["--network=${network}"];
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
          extraOptions = onNetwork;
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

            # Discovery appends the well-known path to this base url itself.
            OPENID_ISSUER = "https://${services.auth.name}/oauth2/openid/librechat";
            OPENID_CLIENT_ID = "librechat";
            OPENID_CALLBACK_URL = "/oauth/openid/callback";
            OPENID_SCOPE = "openid profile email";
            OPENID_BUTTON_LABEL = "Sign in with v3x";
            # Kanidm rejects an authorization code flow without PKCE.
            OPENID_USE_PKCE = "true";

            ALLOW_EMAIL_LOGIN = "false";
            ALLOW_REGISTRATION = "false";
            ALLOW_SOCIAL_LOGIN = "true";
            ALLOW_SOCIAL_REGISTRATION = "true";
          };

          volumes = [
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
          environmentFiles = [config.sops.templates.teapot_librechat_postgres_env.path];

          environment = {
            DB_HOST = "librechat-vectordb";
            DB_PORT = "5432";
            POSTGRES_DB = "librechat";
            POSTGRES_USER = "librechat";
            RAG_PORT = toString ragPort;
          };
        };
      };
    };

    systemd.services =
      lib.genAttrs (map (name: "docker-${name}") containers) (_: {
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
              || ${docker} network create ${network}
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
