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
    v3x-mediabus = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.sops-nix.nixosModules.sops
        inputs.dotfiles-private.nixosModules.pirateship
        inputs.disko.nixosModules.disko
        inputs.kettle-code.nixosModules.default
        inputs.kettle-forge.nixosModules.default
        self.nixosModules.mediabus
        self.nixosModules.mediabusDisko
        self.nixosModules.mediabusPhysical
      ];
    };
  };
}
