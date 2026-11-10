{
  self,
  inputs,
  ...
}: {
  imports = [
    ./configuration.nix
    ./disko.nix
    ./hardware.nix
  ];

  flake.nixosConfigurations = {
    v3x-pink = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
        self.nixosModules.pink
        self.nixosModules.pinkDisko
        self.nixosModules.pinkPhysical
      ];
    };
  };
}
