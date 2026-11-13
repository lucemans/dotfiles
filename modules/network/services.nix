let
  inherit (import ./topology.nix) hub zone;
  inherit (import ./hosts.nix) hosts;
  kettle = import ../services/kettle/topology.nix;
  mail = import ../services/mail/topology.nix;
in {
  records = {
    "77.162.232.110" = ["wg.${zone}"];
    ${hosts.${hub}.address} = [zone];
    ${hosts.${mail.store}.address} = [mail.name];
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
      lan = ["10.0.0.222"];
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
      upstream = "${hosts.v3x-mediabus.address}:8096";
      access = ["f0" "f1" "f2"];
    };
    fmedia = {
      name = "fmedia.${zone}";
      title = "Requests";
      icon = "jellyseerr";
      upstream = "${hosts.v3x-mediabus.address}:5055";
      access = ["f0" "f1" "f2"];
    };
    music = {
      name = "music.${zone}";
      title = "Music";
      icon = "music-assistant";
      upstream = "${hosts.v3x-mediabus.address}:8095";
      access = [];
      lan = ["10.0.0.222"];
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
    ingestarr = {
      name = "ingest.${zone}";
      title = "Ingest";
      icon = "ingestarr";
      upstream = "${hosts.v3x-watch.address}:3100";
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
    usage = {
      name = "usage.${zone}";
      title = "Usage";
      icon = "metered-usage";
      upstream = "${hosts.v3x-watch.address}:3000";
      access = [];
    };
    code = {
      name = "code.${zone}";
      title = "Kettle Code";
      icon = "kettle-code";
      upstream = "${hosts.${kettle.code.host}.address}:${toString kettle.code.port}";
      access = [];
    };
    forge = {
      name = "forge.${zone}";
      title = "Kettle Forge";
      icon = "kettle-forge";
      upstream = "${hosts.${kettle.forge.host}.address}:${toString kettle.forge.port}";
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
    llamaTeapot = {
      name = "llama-t.${zone}";
      title = "Llama Teapot";
      icon = "llama-swap";
      upstream = "127.0.0.1:8081";
      path = "/ui";
      access = [];
    };
    llamaMediabus = {
      name = "llama-m.${zone}";
      title = "Llama Mediabus";
      icon = "llama-swap";
      upstream = "${hosts.v3x-mediabus.address}:11434";
      path = "/ui";
      access = [];
    };
    launchpi = {
      name = "launchpi.${zone}";
      title = "LaunchPi";
      icon = "launchpi";
      upstream = "${hosts.v3x-mission.address}:7778";
      access = [];
    };
    ntfy = {
      name = "ntfy.${zone}";
      title = "Alerts";
      icon = "ntfy";
      upstream = "${hosts.v3x-watch.address}:2586";
      access = [];
    };
    duplex = {
      name = "duplex.${zone}";
      title = "Duplex";
      icon = "bin";
      upstream = "${hosts.v3x-watch.address}:8472";
      access = [];
    };
    shelf = {
      name = "shelf.${zone}";
      title = "Shelf";
      icon = "kavita";
      upstream = "${hosts.v3x-mediabus.address}:5000";
      access = [];
    };
    sinkarr = {
      name = "sinkarr.${zone}";
      title = "Sinkarr";
      icon = "qbit";
      upstream = "${hosts.v3x-mediabus.address}:8080";
      access = [];
    };
    linkarr = {
      name = "linkarr.${zone}";
      title = "Linkarr";
      icon = "prowlarr";
      upstream = "${hosts.v3x-mediabus.address}:9696";
      access = [];
    };
    showarr = {
      name = "showarr.${zone}";
      title = "Showarr";
      icon = "sonar";
      upstream = "${hosts.v3x-mediabus.address}:8989";
      access = [];
    };
    movarr = {
      name = "movarr.${zone}";
      title = "Movarr";
      icon = "radar";
      upstream = "${hosts.v3x-mediabus.address}:7878";
      access = [];
    };
    listenarr = {
      name = "listenarr.${zone}";
      title = "Listenarr";
      icon = "lidarr";
      upstream = "${hosts.v3x-mediabus.address}:8686";
      access = [];
    };
    bookarr = {
      name = "bookarr.${zone}";
      title = "Bookarr";
      icon = "chaptarr";
      upstream = "${hosts.v3x-mediabus.address}:8789";
      access = [];
    };
    titlarr = {
      name = "titlarr.${zone}";
      title = "Titlarr";
      icon = "bazarr";
      upstream = "${hosts.v3x-mediabus.address}:6767";
      access = [];
    };
    coatarr = {
      name = "coatarr.${zone}";
      title = "Coatarr";
      icon = "jackett";
      upstream = "${hosts.v3x-mediabus.address}:9117";
      access = [];
    };
    files = {
      name = "files.${zone}";
      title = "Files";
      icon = "garage";
      upstream = "${hosts.v3x-teapot.address}:3900";
      access = [];
    };
    gallery = {
      name = "gallery.${zone}";
      title = "Photos";
      icon = "immich";
      upstream = "${hosts.v3x-mediabus.address}:2283";
      access = [];
    };
  };

  sections = [
    {
      title = "Home";
      services = ["home" "mealie"];
    }
    {
      title = "Obtain";
      services = ["search" "rss" "ingestarr"];
    }
    {
      title = "Tools";
      services = ["code" "forge" "chat" "duplex" "usage" "agent" "inference" "llamaTeapot" "llamaMediabus"];
    }
    {
      title = "Media";
      services = ["media" "gallery" "fmedia" "music" "shelf"];
    }
    {
      title = "Shiparr";
      services = ["sinkarr" "linkarr" "showarr" "movarr" "listenarr" "bookarr" "titlarr" "coatarr"];
    }
    {
      title = "Control Plane";
      services = ["launchpi" "mission" "grafanaMission" "ntfy"];
    }
    {
      title = "Infrastructure";
      services = ["auth" "bit" "cache" "files"];
    }
  ];
}
