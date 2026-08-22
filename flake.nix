{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    prisma-nixpkgs.url = "github:NixOS/nixpkgs/5ed627539ac84809c78b2dd6d26a5cebeb5ae269";

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

    activate-linux = {
      url = "github:Kaisia-Estrel/activate-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrappers.url = "github:Lassulus/wrappers";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    ethereum-nix = {
      url = "github:nix-community/ethereum.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    launchpi = {
      url = "github:v3xlabs/launchpi";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    koi.url = "github:v3xlabs/koi";

    plan-env-md.url = "github:v3xlabs/plan-env-md";
    eth-data.url = "github:v3xlabs/eth-data";
    midjournal.url = "git+file:///home/luc/dev/local/midjournal";
    gitgui.url = "git+file:///home/luc/dev/local/gitgui";
    auto-commit.url = "git+file:///home/luc/dev/local/auto-commit";
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
