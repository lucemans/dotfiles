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
    v3x-patch = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.nixos-hardware.nixosModules.framework-16-7040-amd
        self.nixosModules.patch
        self.nixosModules.patchPhysical
      ];
    };
  };
}
