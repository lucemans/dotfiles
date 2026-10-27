{
  description = "Luc's NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nur, nixos-hardware }: {
    nixosConfigurations.v3x-patch = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nixos/configuration.nix
        ./hosts/v3x-patch.nix
        nur.modules.nixos.default
        nixos-hardware.nixosModules.framework-16-7040-amd
        home-manager.nixosModules.home-manager
        {
          nixpkgs.overlays = [
            nur.overlays.default
            (final: prev: {
              unstable = import nixpkgs-unstable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            })
          ];
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.luc = import ./home/luc.nix;
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
