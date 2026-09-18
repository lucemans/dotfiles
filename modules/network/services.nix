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
      path = "/ui/";
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
      path = "/management.html";
      access = [];
    };
    mission = {
      name = "mission.${zone}";
      title = "Mission";
      icon = "bin";
      upstream = "${hosts.v3x-mission.address}:3000";
      access = [];
    };
    grafanaMission = {
      name = "grafana-mission.${zone}";
      title = "Mission Grafana";
      icon = "grafana";
      upstream = "${hosts.v3x-mission.address}:3001";
      access = [];
    };
    launchpi = {
      name = "launchpi.${zone}";
      title = "LaunchPi";
      icon = "launchpi";
      upstream = "${hosts.v3x-mission.address}:7778";
      access = [];
    };
    shelf = {
      name = "shelf.${zone}";
      title = "Shelf";
      icon = "kavita";
      upstream = "10.90.0.11:5000";
      access = [];
    };
    sinkarr = {
      name = "sinkarr.${zone}";
      title = "Sinkarr";
      icon = "qbit";
      upstream = "10.90.0.11:8080";
      access = [];
    };
    linkarr = {
      name = "linkarr.${zone}";
      title = "Linkarr";
      icon = "prowlarr";
      upstream = "10.90.0.11:9696";
      access = [];
    };
    showarr = {
      name = "showarr.${zone}";
      title = "Showarr";
      icon = "sonar";
      upstream = "10.90.0.11:8989";
      access = [];
    };
    movarr = {
      name = "movarr.${zone}";
      title = "Movarr";
      icon = "radar";
      upstream = "10.90.0.11:7878";
      access = [];
    };
    listenarr = {
      name = "listenarr.${zone}";
      title = "Listenarr";
      icon = "lidarr";
      upstream = "10.90.0.11:8686";
      access = [];
    };
    bookarr = {
      name = "bookarr.${zone}";
      title = "Bookarr";
      icon = "chaptarr";
      upstream = "10.90.0.11:8789";
      access = [];
    };
    titlarr = {
      name = "titlarr.${zone}";
      title = "Titlarr";
      icon = "bazarr";
      upstream = "10.90.0.11:6767";
      access = [];
    };
    coatarr = {
      name = "coatarr.${zone}";
      title = "Coatarr";
      icon = "jackett";
      upstream = "10.90.0.11:9117";
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
      services = ["chat" "search" "rss" "inference" "agent"];
    }
    {
      title = "Media";
      services = ["media" "fmedia" "shelf"];
    }
    {
      title = "Shiparr";
      services = ["sinkarr" "linkarr" "showarr" "movarr" "listenarr" "bookarr" "titlarr" "coatarr"];
    }
    {
      title = "Infrastructure";
      services = ["auth" "bit" "cache" "mission" "grafanaMission" "launchpi"];
    }
  ];
}
