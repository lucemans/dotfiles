let
  inherit (import ./topology.nix) hub zone;
  inherit (import ./hosts.nix) hosts;
in {
  records = {
    "77.162.232.110" = ["wg.${zone}"];
    ${hosts.${hub}.address} = [zone];
  };

  services = {
    auth = {
      name = "auth.${zone}";
      title = "Identity";
      icon = "kanidm";
      upstream = "https://auth.${zone}:8443";
      access = ["f0" "f1" "f2"];
    };
    cache = {
      name = "cache.${zone}";
      title = "Nix Cache";
      icon = "attic-assets";
      upstream = "${hosts.v3x-teapot.address}:8082";
      access = ["f2"];
    };
    search = {
      name = "search.${zone}";
      title = "Search";
      icon = "searxng";
      upstream = "${hosts.v3x-teapot.address}:8888";
      access = ["f0" "f1" "f2"];
    };
    inference = {
      name = "inference.${zone}";
      title = "Inference";
      icon = "litellm";
      upstream = "${hosts.v3x-teapot.address}:4000";
      access = ["f0" "f1" "f2"];
    };
    mealie = {
      name = "meals.${zone}";
      title = "Recipes";
      icon = "mealie";
      upstream = "${hosts.v3x-teapot.address}:9000";
      access = ["f0"];
    };
    media = {
      name = "media.${zone}";
      title = "Media";
      icon = "jellyfin";
      upstream = "10.90.0.11:8096";
      access = ["f0" "f1" "f2"];
    };
    fmedia = {
      name = "fmedia.${zone}";
      title = "Requests";
      icon = "jellyseerr";
      upstream = "10.90.0.11:5055";
      access = ["f0" "f1" "f2"];
    };
    home = {
      name = "hq53.${zone}";
      title = "Home Assistant";
      icon = "home-assistant";
      upstream = "10.0.0.222:8123";
      access = ["f0"];
    };
    chat = {
      name = "chat.${zone}";
      title = "Chat";
      icon = "librechat";
      upstream = "${hosts.v3x-teapot.address}:3080";
      access = ["f0" "f1" "f2"];
    };
    rss = {
      name = "rss.${zone}";
      title = "Feeds";
      icon = "freshrss";
      upstream = "${hosts.v3x-teapot.address}:8090";
      access = ["f0" "f1" "f2"];
    };
    bit = {
      name = "bit.${zone}";
      title = "Bit";
      icon = "vw";
      upstream = "${hosts.v3x-watch.address}:8222";
      access = [];
    };
    agent = {
      name = "agent.${zone}";
      title = "Inference Proxy";
      icon = "cliproxy";
      upstream = "${hosts.v3x-watch.address}:8317";
      access = [];
    };
  };

  sections = [
    {
      title = "Home";
      services = ["home" "mealie"];
    }
    {
      title = "Tools";
      services = ["chat" "search" "inference" "rss"];
    }
    {
      title = "Media";
      services = ["media" "fmedia"];
    }
    {
      title = "Infrastructure";
      services = ["auth" "bit" "cache" "agent"];
    }
  ];
}
