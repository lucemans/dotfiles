{inputs, ...}: let
  inherit (import ../network/hosts.nix) hosts;
  inherit (import ../network/topology.nix) hub;
in {
  flake.nixosModules.duplex = {config, ...}: {
    imports = [inputs.duplex.nixosModules.default];

    sops.secrets = {
      duplex_server_key = {};
      duplex_telegram_app.restartUnits = ["duplex-server.service"];
    };

    v3x.backup.paths = ["/var/lib/duplex-server"];

    services.duplex-server = {
      enable = true;
      listen = "${config.v3x.address}:8472";
      trustedProxies = [hosts.${hub}.address];
      serverKeyFile = config.sops.secrets.duplex_server_key.path;
      telegram.appFile = config.sops.secrets.duplex_telegram_app.path;
    };

    systemd.services.duplex-server = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
      unitConfig.RequiresMountsFor = ["/var/lib/duplex-server"];
    };
  };

  flake.nixosModules.duplexClient = {pkgs, ...}: {
    users.users.luc.packages = [inputs.duplex.packages.${pkgs.stdenv.hostPlatform.system}.duplex];
  };
}
