{inputs, ...}: let
  inherit (import ../../network/services.nix) services;
in {
  flake.nixosModules.ingestarr = {
    config,
    lib,
    ...
  }: let
    release = {
      key,
      name,
      repo,
      icon ? null,
    }:
      {
        inherit key name;
        kind = "github-releases";
        github-releases = {inherit repo;};
      }
      // lib.optionalAttrs (icon != null) {inherit icon;};
  in {
    imports = [inputs.ingestarr.nixosModules.default];

    sops.secrets.ingestarr_oidc_client_secret.restartUnits = ["ingestarr.service"];

    # v3x.backup.paths = ["/var/lib/private/ingestarr"];

    services.ingestarr = {
      enable = true;
      host = config.v3x.address;
      port = 3100;

      auth = {
        issuer = "https://${services.auth.name}/oauth2/openid/ingestarr";
        baseUrl = "https://${services.ingestarr.name}";
        clientSecretFile = config.sops.secrets.ingestarr_oidc_client_secret.path;
        allowedGroups = ["ingestarr_users@${services.auth.name}"];
      };

      settings = {
        daemon.contact = "luc@v3x.email";

        source = [
          (release {
            key = "kanidm";
            name = "Kanidm";
            repo = "kanidm/kanidm";
            icon = "kanidm";
          })
          (release {
            key = "immich";
            name = "Immich";
            repo = "immich-app/immich";
            icon = "immich";
          })
          (release {
            key = "freshrss";
            name = "FreshRSS";
            repo = "FreshRSS/FreshRSS";
            icon = "freshrss";
          })
          (release {
            key = "vaultwarden";
            name = "Vaultwarden";
            repo = "dani-garcia/vaultwarden";
            icon = "vaultwarden";
          })
          (release {
            key = "cliproxy";
            name = "CLIProxyAPI";
            repo = "router-for-me/CLIProxyAPI";
          })
          (release {
            key = "litellm";
            name = "LiteLLM";
            repo = "BerriAI/litellm";
            icon = "litellm";
          })
          (release {
            key = "llama-cpp";
            name = "llama.cpp";
            repo = "ggml-org/llama.cpp";
            icon = "llama-cpp";
          })
          (release {
            key = "mealie";
            name = "Mealie";
            repo = "mealie-recipes/mealie";
            icon = "mealie";
          })
          (release {
            key = "reth";
            name = "reth";
            repo = "paradigmxyz/reth";
          })
          (release {
            key = "lighthouse";
            name = "Lighthouse";
            repo = "sigp/lighthouse";
          })
          {
            key = "home-assistant";
            name = "Home Assistant";
            kind = "home-assistant";
            icon = "home-assistant";
          }
          {
            key = "nixos-lifecycle";
            name = "NixOS lifecycle";
            kind = "endoflife";
            icon = "nixos";
            endoflife.product = "nixos";
          }
        ];
      };
    };

    systemd.services.ingestarr = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };
  };
}
