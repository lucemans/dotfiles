{ self, inputs, ... }:
{
  flake.nixosConfigurations = {
    fighter = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs self; };
      modules = [
        inputs.disko.nixosModules.disko
        inputs.preservation.nixosModules.default
        self.nixosModules.fighter
        self.nixosModules.environment
        self.nixosModules.develop
        self.nixosModules.desktop
        self.nixosModules.fighterPhysical
        self.nixosModules.fighterPreservation
      ];
    };

    fighter-vm = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs self; };
      modules = [
        inputs.preservation.nixosModules.default
        self.nixosModules.fighter
        self.nixosModules.environment
        self.nixosModules.develop
        self.nixosModules.desktop
        self.nixosModules.plasmaVm
        self.nixosModules.fighterVm
        self.nixosModules.preservation
      ];
    };
  };
}
