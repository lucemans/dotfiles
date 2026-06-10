{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    preservation.url = "github:nix-community/preservation";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    wrappers.url = "github:Lassulus/wrappers";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    ethereum-nix = {
      url = "github:nix-community/ethereum.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        # hosts - fighter
        ./modules/hosts/fighter/default.nix
        ./modules/hosts/fighter/configuration.nix
        ./modules/hosts/fighter/hardware-configuration.nix
        # hosts - point
        ./modules/hosts/point/default.nix
        ./modules/hosts/point/configuration.nix
        ./modules/hosts/point/disko.nix
        ./modules/hosts/point/hardware-configuration.nix
        # features
        ./modules/features/theme/theme.nix
        ./modules/features/zsh.nix
        ./modules/features/kitty.nix
        ./modules/features/plasma-vm.nix
        ./modules/features/develop.nix
        ./modules/features/desktop.nix
        ./modules/features/environment.nix
        ./modules/features/ethereum/mainnet.nix
      ];
    };
}
