{
  self,
  inputs,
  ...
}: {
  imports = [
    ./configuration.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  flake.nixosConfigurations = {
    v3x-point = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.ethereum-nix.nixosModules.default
        inputs.disko.nixosModules.disko
        self.nixosModules.point
        self.nixosModules.pointDisko
        self.nixosModules.pointPhysical
        self.nixosModules.ethereumMainnet
      ];
    };
  };
}
