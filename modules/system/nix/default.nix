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
      trusted-substituters = [
        "https://cache.v3x.host/v3x"
      ];
      trusted-public-keys = ["v3x:KkXZj5H0cOzciurQuabgGocSsZjXZplwgqVWh8Va5s8="];
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
