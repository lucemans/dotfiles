{...}: let
  inherit (import ../network/topology.nix) services;
in {
  flake.nixosModules.freshrss = {
    config,
    lib,
    ...
  }: let
    port = 8090;
    stateDir = "/var/lib/freshrss";
  in {
    sops = {
      secrets.teapot_freshrss_oidc_crypto_key.mode = "0400";

      templates.teapot_freshrss_env = {
        mode = "0400";
        content = ''
          OIDC_CLIENT_SECRET=${config.sops.placeholder.teapot_freshrss_oauth2_secret}
          OIDC_CLIENT_CRYPTO_KEY=${config.sops.placeholder.teapot_freshrss_oidc_crypto_key}
        '';
      };
    };

    systemd.tmpfiles.rules = ["d ${stateDir} 0700 root root -"];

    virtualisation.oci-containers = {
      backend = "docker";

      containers.freshrss = {
        image = "freshrss/freshrss:1.29.1";

        extraOptions = [
          "--network=host"
          "--add-host=${services.auth.name}:${config.v3x.address}"
        ];

        environmentFiles = [config.sops.templates.teapot_freshrss_env.path];

        environment = {
          LISTEN = "${config.v3x.address}:${toString port}";
          TZ = config.time.timeZone;
          CRON_MIN = "*/20";
          BASE_URL = "https://${services.rss.name}";

          OIDC_ENABLED = "1";
          OIDC_PROVIDER_METADATA_URL = "https://${services.auth.name}/oauth2/openid/freshrss/.well-known/openid-configuration";
          OIDC_CLIENT_ID = "freshrss";
          OIDC_SCOPES = "openid profile email";
          OIDC_REMOTE_USER_CLAIM = "preferred_username";
          OIDC_X_FORWARDED_HEADERS = "X-Forwarded-Host X-Forwarded-Proto";

          FRESHRSS_INSTALL = lib.concatStringsSep " " [
            "--auth-type http_auth"
            "--base-url https://${services.rss.name}"
            "--db-type sqlite"
            "--default-user luc"
            "--language en"
          ];
        };

        volumes = ["${stateDir}:/var/www/FreshRSS/data"];
      };
    };

    systemd.services.docker-freshrss = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };
  };
}
