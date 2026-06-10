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
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [
        # hosts - fighter
        ./hosts/fighter/default.nix
        ./hosts/fighter/configuration.nix
        ./hosts/fighter/hardware-configuration.nix
        ./hosts/fighter/thermal.nix
        # hosts - point
        ./hosts/point/default.nix
        ./hosts/point/configuration.nix
        ./hosts/point/disko.nix
        ./hosts/point/hardware-configuration.nix
        # features
        ./modules/theme/theme.nix
        ./modules/zsh.nix
        ./modules/kitty.nix
        ./modules/plasma-vm.nix
        ./modules/develop.nix
        ./modules/gaming.nix
        ./modules/nix.nix
        ./modules/desktop.nix
        ./modules/environment.nix
        ./modules/ethereum/mainnet.nix
      ];
    };
}
