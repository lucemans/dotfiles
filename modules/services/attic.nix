{inputs, ...}: {
  flake.nixosModules.attic = {config, ...}: {
    imports = [
      inputs.attic.nixosModules.atticd
    ];

    sops.secrets.attic_server_token = {
      mode = "0400";
    };

    sops.templates.atticd_env = {
      mode = "0400";
      content = ''
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder.attic_server_token}
      '';
    };

    services.atticd = {
      enable = true;

      environmentFile = config.sops.templates.atticd_env.path;

      settings = {
        listen = "${config.v3x.address}:8082";
        api-endpoint = "https://cache.v3x.host";
        jwt = {};
        garbage-collection = {
          interval = "12 hours";
          default-retention-period = "3 months";
        };
        chunking = {
          # The minimum NAR size to trigger chunking
          #
          # If 0, chunking is disabled entirely for newly-uploaded NARs.
          # If 1, all NARs are chunked.
          nar-size-threshold = 64 * 1024; # 64 KiB

          # The preferred minimum size of a chunk, in bytes
          min-size = 16 * 1024; # 16 KiB

          # The preferred average size of a chunk, in bytes
          avg-size = 64 * 1024; # 64 KiB

          # The preferred maximum size of a chunk, in bytes
          max-size = 256 * 1024; # 256 KiB
        };
      };
    };

    # listen binds a tunnel address that does not exist until wg0 is up.
    systemd.services.atticd = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };
  };
}
