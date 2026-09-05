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
    v3x-voice = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs self;};
      modules = [
        inputs.sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
        inputs.voice-channel.nixosModules.default
        self.nixosModules.voice
        self.nixosModules.voiceDisko
        self.nixosModules.voicePhysical
      ];
    };
  };
}
