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
    v3x-watch = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.disko.nixosModules.disko
        inputs.preservation.nixosModules.preservation
        self.nixosModules.watch
        self.nixosModules.watchDisko
        self.nixosModules.watchPhysical
      ];
    };
  };
}
