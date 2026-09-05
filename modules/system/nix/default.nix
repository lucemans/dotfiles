{inputs, ...}: {
  imports = [
    ./deploy.nix
  ];

  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  };

  flake.nixosModules.nix = {
    self,
    config,
    lib,
    pkgs,
    ...
  }: let
    onTunnel = config.networking.wireguard.interfaces ? wg0;
  in {
    imports = [
      self.nixosModules.rollout
    ];
    # programs.nix-index-database.comma.enable = true;

    nix.settings.experimental-features = ["nix-command" "flakes"];
    programs.nix-ld.enable = true;
    nixpkgs.config.allowUnfree = true;

    nix.gc.automatic = true;

    # cache.v3x.host resolves and routes only over the wg0 tunnel.
    nix.settings = {
      substituters = lib.mkIf onTunnel ["https://cache.v3x.host/v3x"];
      trusted-public-keys = lib.mkIf onTunnel ["v3x:KkXZj5H0cOzciurQuabgGocSsZjXZplwgqVWh8Va5s8="];
      fallback = true;
      connect-timeout = 5;
      download-attempts = 3;
    };

    environment.systemPackages = with pkgs; [
      # inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.attic
      nil
      nixd
      statix
      alejandra
      manix
      nix-inspect
      nh
    ];
  };
}
