{
  self,
  inputs,
  ...
}: {
  imports = [
    ./configuration.nix
    ./hardware.nix
  ];

  flake.nixosConfigurations = {
    v3x-generator = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.generator
        self.nixosModules.generatorPhysical
      ];
    };
  };
}
