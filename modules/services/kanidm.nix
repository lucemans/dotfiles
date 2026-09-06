{...}: let
  inherit (import ../network/topology.nix) zone services;
in {
  flake.nixosModules.kanidm = {
    config,
    pkgs,
    ...
  }: let
    certificates = config.security.acme.certs.${zone}.directory;
  in {
    services.kanidm = {
      # Provisioning an oauth2 basic secret needs the patched build.
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

        # The server binds the tunnel address only, so the localhost default
        # never connects.
        instanceUrl = "https://${services.auth.name}:8443";
        idmAdminPasswordFile = config.sops.secrets.teapot_kanidm_idm_admin_password.path;

        groups.librechat_users = {};

        persons.luc = {
          displayName = "Luc";
          mailAddresses = ["luc@v3x.email"];
          groups = ["librechat_users"];
        };

        systems.oauth2.librechat = {
          displayName = "LibreChat";
          originUrl = "https://${services.chat.name}/oauth/openid/callback";
          originLanding = "https://${services.chat.name}";
          basicSecretFile = config.sops.secrets.teapot_librechat_oauth2_secret.path;
          preferShortUsername = true;
          scopeMaps.librechat_users = ["openid" "profile" "email"];
        };
      };
    };

    # Provisioning reads these as the kanidm user, not as root.
    sops.secrets = {
      teapot_kanidm_idm_admin_password = {
        owner = "kanidm";
        mode = "0400";
      };
      teapot_librechat_oauth2_secret = {
        owner = "kanidm";
        mode = "0400";
      };
    };

    # The wildcard certificate is readable by the caddy group only.
    users.users.kanidm.extraGroups = ["caddy"];

    # Kanidm reads the certificate once, so a renewal needs a restart.
    security.acme.certs.${zone}.reloadServices = ["kanidm.service"];

    # bindaddress is a tunnel address that does not exist until wg0 is up.
    systemd.services.kanidm = {
      after = ["wireguard-wg0.service" "acme-finished-${zone}.target"];
      wants = ["wireguard-wg0.service" "acme-finished-${zone}.target"];
    };
  };
}
