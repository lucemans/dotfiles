{
  imports = [
    ./deploy.nix
  ];

  flake.nixosModules.nix = {
    self,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.rollout
    ];
    # programs.nix-index-database.comma.enable = true;

    nix.settings.experimental-features = ["nix-command" "flakes"];
    programs.nix-ld.enable = true;
    nixpkgs.config.allowUnfree = true;

    nix.settings = {
      substituters = [
        "https://cache.v3x.host/v3x"
      ];
      trusted-public-keys = ["v3x:KkXZj5H0cOzciurQuabgGocSsZjXZplwgqVWh8Va5s8="];
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
