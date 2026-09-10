_: let
  inherit (import ../network/services.nix) services;
in {
  flake.nixosModules.vaultwarden = {config, ...}: let
    port = 8222;
    stateDir = "/var/lib/vaultwarden";
  in {
    systemd.tmpfiles.rules = ["d ${stateDir} 0700 root root -"];

    virtualisation.oci-containers = {
      backend = "docker";

      containers.vaultwarden = {
        image = "vaultwarden/server:1.37.2-alpine";

        extraOptions = ["--network=host"];

        environment = {
          DOMAIN = "https://${services.bit.name}";
          ROCKET_ADDRESS = config.v3x.address;
          ROCKET_PORT = toString port;
          TZ = config.time.timeZone;

          SIGNUPS_ALLOWED = "false";
          INVITATIONS_ALLOWED = "true";
          SHOW_PASSWORD_HINT = "false";
        };

        volumes = ["${stateDir}:/data"];
      };
    };

    systemd.services.docker-vaultwarden = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };
  };
}
