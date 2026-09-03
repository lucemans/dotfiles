{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    prisma-nixpkgs.url = "github:NixOS/nixpkgs/5ed627539ac84809c78b2dd6d26a5cebeb5ae269";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    preservation.url = "github:nix-community/preservation";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    wrappers.url = "github:Lassulus/wrappers";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    activate-linux.url = "github:Kaisia-Estrel/activate-linux";
    activate-linux.inputs.nixpkgs.follows = "nixpkgs";
    ethereum-nix.url = "github:nix-community/ethereum.nix";
    ethereum-nix.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    launchpi.url = "github:v3xlabs/launchpi";
    launchpi.inputs.nixpkgs.follows = "nixpkgs";
    koi.url = "github:v3xlabs/koi";
    koi.inputs.nixpkgs.follows = "nixpkgs";
    plan-env-md.url = "github:v3xlabs/plan-env-md";
    plan-env-md.inputs.nixpkgs.follows = "nixpkgs";
    eth-data.url = "github:v3xlabs/eth-data";
    eth-data.inputs.nixpkgs.follows = "nixpkgs";
    auto-commit.url = "github:v3xlabs/auto-commit";
    auto-commit.inputs.nixpkgs.follows = "nixpkgs";
    gitgui.url = "github:v3xlabs/gg";
    gitgui.inputs.nixpkgs.follows = "nixpkgs";
    tablet.url = "github:v3xlabs/tablet";
    tablet.inputs.nixpkgs.follows = "nixpkgs";
    midjournal.url = "github:lucemans/midjournal";
    midjournal.inputs.nixpkgs.follows = "nixpkgs";
    missiond.url = "github:v3xlabs/missiond";
    missiond.inputs.nixpkgs.follows = "nixpkgs";

    attic.url = "github:zhaofengli/attic";
    voxtype.url = "github:peteonrails/voxtype";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [
        inputs.home-manager.flakeModules.home-manager
        ./hosts
        ./modules
      ];
    };
}
