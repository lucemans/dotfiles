{inputs, ...}: let
  inherit (import ../../network/services.nix) services;
in {
  flake.nixosModules.kettleClient = {pkgs, ...}: let
    inherit (pkgs.stdenv.hostPlatform) system;
  in {
    users.users.luc.packages = [
      inputs.kettle-forge.packages.${system}.k5f
    ];

    home-manager.users.luc.home.sessionVariables.K5F_URL = "https://${services.forge.name}";
  };
}
