{
  self,
  ...
}: {
  flake.nixosModules.audio = {
    pkgs,
    lib,
    ...
  }: {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber = {
        extraConfig."50-scarlett-routing" = {
          "monitor.alsa.rules" = [
            {
              matches = [
                {
                  "node.description" = "Scarlett 18i20 3rd Gen Line Output 1+2";
                }
              ];
              actions.update-props = {
                "node.name" = "scarlett-1+2";
                "priority.session" = 9999;
              };
            }
            {
              matches = [
                {
                  "node.description" = "Scarlett 18i20 3rd Gen Line Output 5+6";
                }
              ];
              actions.update-props."node.name" = "scarlett-5+6";
            }
          ];

          "wireplumber.components" = [
            {
              name = "spotify-routing.lua";
              type = "script/lua";
              provides = "custom.spotify-routing";
            }
          ];

          "wireplumber.profiles" = {
            main."custom.spotify-routing" = "required";
          };
        };

        extraScripts."spotify-routing.lua" = builtins.readFile ./wireplumber/spotify-routing.lua;
      };
    };

    users.users.luc.extraGroups = lib.mkAfter ["audio" "realtime"];

    environment.systemPackages = with pkgs; [
      qpwgraph
      wireplumber
    ];
  };
}
