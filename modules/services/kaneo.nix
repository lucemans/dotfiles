_: let
  inherit (import ../network/services.nix) services;
in {
  flake.nixosModules.kaneo = {config, ...}: {
    sops = {
      secrets.teapot_kaneo_auth_secret.mode = "0400";

      templates.teapot_kaneo_env = {
        mode = "0400";
        content = ''
          AUTH_SECRET=${config.sops.placeholder.teapot_kaneo_auth_secret}
          CUSTOM_OAUTH_CLIENT_SECRET=${config.sops.placeholder.teapot_kaneo_oauth2_secret}
          S3_ACCESS_KEY_ID=${config.sops.placeholder.teapot_garage_kaneo_key_id}
          S3_SECRET_ACCESS_KEY=${config.sops.placeholder.teapot_garage_kaneo_secret_key}
        '';
      };
    };

    services.postgresql = {
      enable = true;
      authentication = ''
        host kaneo kaneo 127.0.0.1/32 trust
      '';
      ensureDatabases = ["kaneo"];
      ensureUsers = [
        {
          name = "kaneo";
          ensureDBOwnership = true;
        }
      ];
    };

    virtualisation.oci-containers = {
      backend = "docker";

      containers.kaneo = {
        image = "ghcr.io/usekaneo/kaneo:2.35.0";

        # The image serves its web app on 5173 and its API on 1337, on every
        # address. Only the trusted tunnel subnet passes the firewall to either.
        extraOptions = [
          "--network=host"
          "--add-host=${services.auth.name}:${config.v3x.address}"
          "--add-host=${services.files.name}:${config.v3x.address}"
        ];

        environmentFiles = [config.sops.templates.teapot_kaneo_env.path];

        environment = {
          KANEO_CLIENT_URL = "https://${services.tasks.name}";
          DATABASE_URL = "postgresql://kaneo@127.0.0.1:5432/kaneo";

          # Browsers upload to this endpoint directly, so it is the public
          # name rather than Garage's own address.
          S3_ENDPOINT = "https://${services.files.name}";
          S3_BUCKET = "kaneo-uploads";
          S3_REGION = "garage";
          S3_FORCE_PATH_STYLE = "true";

          DISABLE_GUEST_ACCESS = "true";
          DISABLE_PASSWORD_REGISTRATION = "true";
          DISABLE_LOGIN_FORM = "true";

          CUSTOM_OAUTH_CLIENT_ID = "kaneo";
          CUSTOM_OAUTH_DISCOVERY_URL = "https://${services.auth.name}/oauth2/openid/kaneo/.well-known/openid-configuration";
          CUSTOM_OAUTH_AUTHORIZATION_URL = "https://${services.auth.name}/ui/oauth2";
          CUSTOM_OAUTH_TOKEN_URL = "https://${services.auth.name}/oauth2/token";
          CUSTOM_OAUTH_USER_INFO_URL = "https://${services.auth.name}/oauth2/openid/kaneo/userinfo";
          CUSTOM_OAUTH_SCOPES = "openid,profile,email";
          CUSTOM_OAUTH_AUTO_LOGIN = "true";
        };
      };
    };

    systemd.services.docker-kaneo = {
      requires = ["postgresql.service"];
      after = ["postgresql.service" "wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };
  };
}
