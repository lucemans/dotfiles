{
  self,
  inputs,
  ...
}: {
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./thermal.nix
  ];

  flake.nixosConfigurations = {
    v3x-fighter = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.sops-nix.nixosModules.sops
        inputs.lanzaboote.nixosModules.lanzaboote
        self.nixosModules.fighter
        self.nixosModules.fighterPhysical
        self.nixosModules.fighterThermal
      ];
    };
  };
}
