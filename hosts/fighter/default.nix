{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations = {
    v3x-fighter = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        # inputs.disko.nixosModules.disko
        # inputs.preservation.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        inputs.lanzaboote.nixosModules.lanzaboote
        self.nixosModules.fighter
        self.nixosModules.audio
        self.nixosModules.environment
        self.nixosModules.develop
        self.nixosModules.desktop
        self.nixosModules.gnome-calls
        # self.nixosModules.fusion360
        self.nixosModules.gaming
        self.nixosModules.nix
        self.nixosModules.searxng
        self.nixosModules.fighterPhysical
        self.nixosModules.fighterThermal
      ];
    };
  };
}
