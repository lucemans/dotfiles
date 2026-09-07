{...}: let
  inherit (import ../network/services.nix) services;
in {
  flake.nixosModules.mealie = {config, ...}: {
    services.mealie = {
      enable = true;
      listenAddress = config.v3x.address;
      port = 9000;

      settings = {
        BASE_URL = "https://${services.mealie.name}";
      };
    };

    # listenAddress binds a tunnel address that does not exist until wg0 is up.
    systemd.services.mealie = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };
  };
}
