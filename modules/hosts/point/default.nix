{ self, inputs, ... }:
{
  flake.nixosConfigurations = {
    point = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs self; };
      modules = [
        inputs.ethereum-nix.nixosModules.default
        inputs.disko.nixosModules.disko
        self.nixosModules.point
        self.nixosModules.pointDisko
        self.nixosModules.environment
        self.nixosModules.pointPhysical

        (
          { pkgs, ... }:
          {
            environment.systemPackages = (
              with inputs.ethereum-nix.packages.${pkgs.system};
              [
                lighthouse
                reth
              ]
            );
          }
        )
      ];
    };
  };
}
