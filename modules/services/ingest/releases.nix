_: {
  flake.nixosModules.ingestarrReleases = {lib, ...}: let
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
    services.ingestarr = {
      settings.source = [
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
      ];

      collections = [
        {
          name = "selfhosted";
          title = "Self-hosted";
          kinds = ["github-releases" "home-assistant"];
        }
      ];
    };
  };
}
