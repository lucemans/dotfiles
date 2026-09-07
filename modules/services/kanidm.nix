{...}: let
  inherit (import ../network/topology.nix) zone;
  inherit (import ../network/services.nix) services;
in {
  flake.nixosModules.kanidm = {
    config,
    pkgs,
    ...
  }: let
    certificates = config.security.acme.certs.${zone}.directory;
  in {
    services.kanidm = {
      package = pkgs.kanidmWithSecretProvisioning_1_11;

      server = {
        enable = true;
        settings = {
          bindaddress = "${config.v3x.address}:8443";
          domain = services.auth.name;
          origin = "https://${services.auth.name}";
          tls_chain = "${certificates}/fullchain.pem";
          tls_key = "${certificates}/key.pem";
        };
      };

      client = {
        enable = true;
        settings.uri = "https://${services.auth.name}";
      };

      provision = {
        enable = true;

        instanceUrl = "https://${services.auth.name}:8443";
        idmAdminPasswordFile = config.sops.secrets.teapot_kanidm_idm_admin_password.path;

        groups.librechat_users = {};
        groups.freshrss_users = {};
        groups.litellm_users = {};

        persons.luc = {
          displayName = "Luc";
          mailAddresses = ["luc@v3x.email"];
          groups = ["librechat_users" "freshrss_users" "litellm_users"];
        };

        systems.oauth2.librechat = {
          displayName = services.chat.title;
          originUrl = "https://${services.chat.name}/oauth/openid/callback";
          originLanding = "https://${services.chat.name}";
          basicSecretFile = config.sops.secrets.teapot_librechat_oauth2_secret.path;
          preferShortUsername = true;
          scopeMaps.librechat_users = ["openid" "profile" "email"];
        };

        systems.oauth2.litellm = {
          displayName = services.inference.title;
          originUrl = "https://${services.inference.name}/oauth/openid/callback";
          originLanding = "https://${services.inference.name}";
          basicSecretFile = config.sops.secrets.teapot_litellm_oauth2_secret.path;
          preferShortUsername = true;
          scopeMaps.litellm_users = ["openid" "profile" "email"];
        };

        systems.oauth2.freshrss = {
          displayName = services.rss.title;
          originUrl = "https://${services.rss.name}/i/oidc/";
          originLanding = "https://${services.rss.name}";
          basicSecretFile = config.sops.secrets.teapot_freshrss_oauth2_secret.path;
          preferShortUsername = true;
          scopeMaps.freshrss_users = ["openid" "profile" "email"];
        };
      };
    };

    sops.secrets = {
      teapot_kanidm_idm_admin_password = {
        owner = "kanidm";
        mode = "0400";
      };
      teapot_librechat_oauth2_secret = {
        owner = "kanidm";
        mode = "0400";
      };
      teapot_litellm_oauth2_secret = {
        owner = "kanidm";
        mode = "0400";
      };
      teapot_freshrss_oauth2_secret = {
        owner = "kanidm";
        mode = "0400";
      };
    };

    users.users.kanidm.extraGroups = ["caddy"];
    security.acme.certs.${zone}.reloadServices = ["kanidm.service"];

    systemd.services.kanidm = {
      after = ["wireguard-wg0.service" "acme-finished-${zone}.target"];
      wants = ["wireguard-wg0.service" "acme-finished-${zone}.target"];
    };
  };
}
