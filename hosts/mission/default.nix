{
  self,
  inputs,
  ...
}: {
  imports = [
    ./configuration.nix
    ./disko.nix
  ];

  flake.nixosConfigurations = {
    v3x-mission = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.disko.nixosModules.disko
        self.nixosModules.mission
        self.nixosModules.missionDisko
      ];
    };
  };
}
