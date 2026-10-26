_: let
  inherit (import ./topology.nix) code machines;
  inherit (import ../../network/hosts.nix) hosts;
  inherit (import ../../network/services.nix) services;
in {
  # Needs inputs.kettle-code.nixosModules.default.
  flake.nixosModules.kettleCode = {config, ...}: {
    assertions = [
      {
        assertion = config.networking.hostName == code.host;
        message = "kettleCode is imported on ${config.networking.hostName}, but modules/services/kettle/topology.nix names ${code.host} as k5c's host.";
      }
    ];

    # Also declared by kettleRunner; the same empty declaration merges.
    sops.secrets.v3x_inference_token = {};

    # No firewall port: the hub's proxy and editors come over wg0, which
    # already accepts the trusted subnet.
    services.kettle-code = {
      enable = true;
      bind = "0.0.0.0:${toString code.port}";
      publicUrl = "https://${services.code.name}";
      inherit machines;

      editorSsh = {
        listen = "0.0.0.0:${toString code.editorSshPort}";
        publicAddress = "${hosts.${code.host}.address}:${toString code.editorSshPort}";
        openFirewall = false;
      };

      # As Luc chose them in the playtest.
      runRetentionDays = 30;
      runBuildOutputHours = 4;
      runUnsettledBuildOutputDays = 14;
      runPowerDownSecs = 60;

      modelRoutes = [
        {
          prefix = "v3x-inference/openrouter/";
          label = "OpenRouter";
          mark = "openrouter";
        }
      ];

      # A new database turns `metered_usage` and `litellm_proxy` off, so all
      # six are listed. metered_usage prices nothing until metered-usage is
      # connected in Settings.
      prices.sources = ["manual" "harness" "metered_usage" "litellm_proxy" "litellm_public" "openrouter"];

      chatTitles = {
        generator = "endpoint";
        endpoint = {
          baseUrl = "https://${services.inference.name}/v1";
          model = "v3x-m/nex-n2.5-mini";
          apiKeyFile = config.sops.secrets.v3x_inference_token.path;
        };
      };

      # No `integrations.forge`: the forge connection stays the one in the
      # database moved from the playtest. A configured URL or token that
      # differs from it reconnects, which resets the event cursor and wakes
      # PR-bound chats again.

      # For its cost map (the `litellm_proxy` price source).
      integrations.litellm = {
        url = "https://${services.inference.name}";
        keyFile = config.sops.secrets.v3x_inference_token.path;
      };
    };
  };
}
