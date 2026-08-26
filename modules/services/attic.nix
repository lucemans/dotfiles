{inputs, ...}: {
  flake.nixosModules.attic = {config, ...}: {
    imports = [
      inputs.attic.nixosModules.atticd
    ];

    sops.secrets.atticd_server_token = {
      mode = "0400";
    };

    sops.templates.atticd_env = {
      mode = "0400";
      user = "atticd";
      content = ''
        ATTIC_SERVER_TOKEN_RS256_SECRET=${config.sops.placeholder.atticd_server_token}
      '';
    };

    services.atticd = {
      enable = true;

      environmentFile = config.sops.templates.teapot_litellm_env.path;

      settings = {
        listen = "[::]:8080";
        jwt = {};
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
  };
}
