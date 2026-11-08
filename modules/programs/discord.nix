{
  flake.nixosModules.discord = {
    inputs,
    pkgs,
    ...
  }: let
    discordPkgs = import inputs.nixpkgs-discord {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  in {
    users.users.luc.packages = [
      (discordPkgs.discord.override {
        withVencord = true;
      })
    ];
  };
}
