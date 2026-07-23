{
  flake.nixosModules.discord = {
    lib,
    pkgs,
    ...
  }: {
    nixpkgs.overlays = [
      (_: prev: let
        fetchDiscordArchive = args:
          prev.fetchurl (args
            // {
              # Discord's CDN resets Nixpkgs curl requests but accepts this browser-like HTTP/1.1 request.
              curlOptsList =
                (args.curlOptsList or [])
                ++ [
                  "--http1.1"
                  "--user-agent"
                  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"
                ];
            });
        discordScope =
          prev
          // {
            fetchurl = fetchDiscordArchive;
            callPackage = lib.callPackageWith discordScope;
          };
      in {
        discord = (discordScope.callPackage "${prev.path}/pkgs/applications/networking/instant-messengers/discord/default.nix" {}).discord;
      })
    ];

    home-manager.users.luc.home.packages = [
      (pkgs.discord.override {
        withVencord = true;
      })
    ];
  };
}
