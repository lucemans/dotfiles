{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations = {
    v3x-mission = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.disko.nixosModules.disko
        self.nixosModules.mission
        self.nixosModules.missionDisko
        self.nixosModules.nix
        self.nixosModules.environment
        # self.nixosModules.missionPhysical
      ];
    };
  };
}
