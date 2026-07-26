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
    v3x-teapot = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
        inputs.hermes-agent.nixosModules.default
        self.nixosModules.teapot
        self.nixosModules.teapotDisko
        self.nixosModules.teapotPhysical
      ];
    };
  };
}
