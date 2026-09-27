_: {
  flake.nixosModules.spotify = {pkgs, ...}: {
    services.pipewire.wireplumber = {
      extraConfig."50-spotify-routing" = {
        "wireplumber.components" = [
          {
            name = "spotify-routing.lua";
            type = "script/lua";
            provides = "custom.spotify-routing";
          }
        ];

        "wireplumber.profiles".main."custom.spotify-routing" = "required";
      };

      extraScripts."spotify-routing.lua" = builtins.readFile ../system/audio/wireplumber/spotify-routing.lua;
    };

    users.users.luc.packages = [pkgs.spotify];
  };
}
