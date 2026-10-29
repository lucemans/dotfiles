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

    statuspage = {
      key,
      name,
      url,
      icon,
    }: {
      inherit key name icon;
      kind = "statuspage";
      statuspage = {inherit url;};
    };
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
          {
            key = "linux-lifecycle";
            name = "Linux lifecycle";
            kind = "endoflife";
            icon = "linux";
            endoflife.product = "linux";
          }
          {
            key = "postgresql-lifecycle";
            name = "PostgreSQL 15 lifecycle";
            kind = "endoflife";
            icon = "postgresql";
            endoflife = {
              product = "postgresql";
              cycles = ["15"];
            };
          }
          (statuspage {
            key = "github-status";
            name = "GitHub status";
            url = "https://www.githubstatus.com";
            icon = "github";
          })
          (statuspage {
            key = "cloudflare-status";
            name = "Cloudflare status";
            url = "https://www.cloudflarestatus.com";
            icon = "cloudflare";
          })
          (statuspage {
            key = "claude-status";
            name = "Claude status";
            url = "https://status.claude.com";
            icon = "claude";
          })
          (statuspage {
            key = "openai-status";
            name = "OpenAI status";
            url = "https://status.openai.com";
            icon = "openai";
          })
          {
            key = "cisa-kev";
            name = "CISA exploited vulnerabilities";
            kind = "cisa-kev";
          }
          {
            key = "hacker-news";
            name = "Hacker News";
            kind = "hackernews";
            icon = "hacker-news";
            interval = "30m";
            hackernews = {
              list = "top";
              top_n = 30;
              min_points = 250;
            };
          }
          {
            key = "arxiv-cl";
            name = "arXiv cs.CL";
            kind = "arxiv";
            arxiv = {
              category = "cs.CL";
              keywords = ["speculative decoding" "diffusion language model" "KV cache"];
            };
          }
          {
            key = "hf-ggml-org";
            name = "Hugging Face ggml-org";
            kind = "huggingface";
            icon = "llama-cpp";
            huggingface.author = "ggml-org";
          }
          {
            key = "hf-qwen";
            name = "Hugging Face Qwen";
            kind = "huggingface";
            huggingface.author = "Qwen";
          }
          {
            key = "hf-trending-text";
            name = "Hugging Face trending text models";
            kind = "huggingface";
            huggingface = {
              trending = "models";
              pipeline_tag = "text-generation";
              top = 10;
            };
          }
          {
            key = "librechat-image";
            name = "LibreChat image";
            kind = "container-registry";
            icon = "librechat";
            container-registry = {
              image = "registry.librechat.ai/danny-avila/librechat-dev";
              track = "latest";
            };
          }
          {
            key = "vllm-omni-image";
            name = "vLLM-Omni image";
            kind = "container-registry";
            icon = "vllm";
            container-registry = {
              image = "vllm/vllm-omni";
              tags = ''^v\d+\.\d+\.\d+$'';
            };
          }
          {
            key = "claude-code-npm";
            name = "Claude Code";
            kind = "package";
            icon = "claude";
            package = {
              registry = "npm";
              name = "@anthropic-ai/claude-code";
            };
          }
        ];
      };

      collections = [
        {
          name = "status";
          title = "Status";
          kinds = ["statuspage"];
        }
      ];
    };

    systemd.services.ingestarr = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
      unitConfig.RequiresMountsFor = ["/var/lib/private/ingestarr"];
    };
  };
}
