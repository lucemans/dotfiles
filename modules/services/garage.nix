_: let
  inherit (import ../network/services.nix) services;
in {
  flake.nixosModules.garage = {
    config,
    lib,
    pkgs,
    ...
  }: let
    garage = lib.getExe config.services.garage.package;
    bucket = "kaneo-uploads";

    # The CLI talks to the server over RPC, so the rule is set without an
    # admin API token. Browsers upload straight to the bucket with presigned
    # PUTs, which needs this rule for the Kaneo origin.
    cors = pkgs.writeShellScript "garage-kaneo-cors" ''
      until ${garage} status >/dev/null 2>&1; do
        sleep 1
      done
      id="$(${garage} json-api GetBucketInfo '{"globalAlias":"${bucket}"}' | ${lib.getExe pkgs.jq} -r .id)"
      ${garage} json-api UpdateBucket "$(${lib.getExe pkgs.jq} -nc --arg id "$id" '{
        id: $id,
        body: {corsRules: [{
          AllowedOrigin: ["https://${services.tasks.name}"],
          AllowedMethod: ["GET", "HEAD", "PUT"],
          AllowedHeader: ["*"],
          ExposeHeader: ["ETag"]
        }]}
      }')" >/dev/null
    '';
  in {
    sops = {
      secrets = {
        teapot_garage_rpc_secret.mode = "0400";
        teapot_garage_kaneo_key_id.mode = "0400";
        teapot_garage_kaneo_secret_key.mode = "0400";
      };

      templates.teapot_garage_env = {
        mode = "0400";
        content = ''
          GARAGE_RPC_SECRET=${config.sops.placeholder.teapot_garage_rpc_secret}
          GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder.teapot_garage_kaneo_key_id}
          GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder.teapot_garage_kaneo_secret_key}
        '';
      };
    };

    services.garage = {
      enable = true;
      package = pkgs.garage_2;
      environmentFile = config.sops.templates.teapot_garage_env.path;
      extraEnvironment.GARAGE_DEFAULT_BUCKET = bucket;

      settings = {
        replication_factor = 1;
        db_engine = "sqlite";
        rpc_bind_addr = "127.0.0.1:3901";
        s3_api = {
          api_bind_addr = "${config.v3x.address}:3900";
          s3_region = "garage";
        };
      };
    };

    systemd.services.garage = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
      # Single-node mode lays out this node and imports the key and bucket
      # named in the environment file on each start, so none of it is state
      # set up by hand.
      serviceConfig = {
        ExecStart = lib.mkForce "${garage} server --single-node --default-bucket";
        ExecStartPost = cors;
      };
    };
  };
}
