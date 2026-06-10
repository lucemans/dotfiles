{ self, inputs, ... }:
{
  flake.nixosConfigurations = {
    fighter = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs self; };
      modules = [
        # inputs.disko.nixosModules.disko
        # inputs.preservation.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.fighter
        # self.nixosModules.environment
        # self.nixosModules.develop
        self.nixosModules.desktop
        self.nixosModules.gaming
        self.nixosModules.fighterPhysical
        self.nixosModules.fighterThermal
      ];
    };
  };
}
