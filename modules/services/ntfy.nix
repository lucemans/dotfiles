_: let
  inherit (import ../network/services.nix) services;

  reader = "luc";
  alerts = ["mail" "infra" "security" "noise"];
  publishers = {
    asterisk = ["voicemail"];
    mission = alerts;
  };
in {
  flake.nixosModules.ntfy = {
    config,
    lib,
    ...
  }: let
    inherit (config.sops) placeholder;
    publisherNames = lib.attrNames publishers;
    userNames = [reader] ++ publisherNames;

    hash = name: "ntfy_hash_${name}";
    token = name: "ntfy_token_${name}";
  in {
    sops = {
      secrets = lib.genAttrs (map hash userNames ++ map token publisherNames) (_: {});

      templates.ntfy-env = {
        restartUnits = ["ntfy-sh.service"];
        content = ''
          NTFY_AUTH_USERS='${lib.concatMapStringsSep "," (name: "${name}:${placeholder.${hash name}}:user") userNames}'
          NTFY_AUTH_TOKENS='${lib.concatMapStringsSep "," (name: "${name}:${placeholder.${token name}}") publisherNames}'
        '';
      };
    };

    v3x.backup.paths = ["/var/lib/private/ntfy-sh"];

    services.ntfy-sh = {
      enable = true;
      environmentFile = config.sops.templates.ntfy-env.path;
      settings = {
        base-url = "https://${services.ntfy.name}";
        listen-http = "${config.v3x.address}:2586";
        behind-proxy = true;

        auth-default-access = "deny-all";
        auth-access =
          ["${reader}:*:read-only"]
          ++ lib.concatLists (lib.mapAttrsToList (name: map (topic: "${name}:${topic}:write-only")) publishers);
        enable-login = true;

        cache-duration = "7d";
        attachment-expiry-duration = "7d";
      };
    };

    systemd.services.ntfy-sh = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
      unitConfig.RequiresMountsFor = ["/var/lib/private/ntfy-sh"];
    };
  };
}
