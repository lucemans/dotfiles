_: let
  inherit (import ./topology.nix) forge;
  inherit (import ../../network/hosts.nix) hosts;
  inherit (import ../../network/services.nix) services;
in {
  # Needs inputs.kettle-forge.nixosModules.default.
  flake.nixosModules.kettleForge = {config, ...}: {
    assertions = [
      {
        assertion = config.networking.hostName == forge.host;
        message = "kettleForge is imported on ${config.networking.hostName}, but modules/services/kettle/topology.nix names ${forge.host} as the forge's host.";
      }
    ];

    sops.secrets = {
      kettle_forge_oidc_client_secret.mode = "0400";
      kettle_forge_github_token.mode = "0400";
    };

    # No firewall port: wg0 already accepts the trusted subnet.
    services.kettle-forge = {
      enable = true;
      oidcClientSecretFile = config.sops.secrets.kettle_forge_oidc_client_secret.path;
      githubTokenFile = config.sops.secrets.kettle_forge_github_token.path;
      settings = {
        # Reached on lo and wg0 only: no firewall port is opened, and wg0
        # accepts the trusted subnet.
        listen = "0.0.0.0:${toString forge.port}";
        # The playtest forge's host. Agent commit emails are
        # `<model>@agents.<host>`, and commits by another host's identity are
        # flagged `identity_mismatch`.
        host = "forge.localhost";
        web = {
          public_url = "https://${services.forge.name}";
          # The playtest k5c on fighter.
          allowed_origins = [
            "http://127.0.0.1:3600"
            "http://${hosts.v3x-fighter.address}:3600"
          ];
        };
        ssh.listen = "0.0.0.0:${toString forge.sshPort}";
        oidc = {
          issuer = "https://${services.auth.name}/oauth2/openid/kettle-forge";
          client_id = "kettle-forge";
        };
      };
    };

    # For `kettle-forge admin` and `k5f` on the host.
    environment.systemPackages = [config.services.kettle-forge.package];
  };
}
