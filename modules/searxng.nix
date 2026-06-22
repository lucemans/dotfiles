{inputs, ...}: {
  flake.nixosModules.searxng = {
    pkgs,
    config,
    lib,
    ...
  }: {
    sops.age.keyFile = "/home/luc/.config/sops/age/keys.txt";
    sops.defaultSopsFile = ../secrets/secrets.sops.yaml;
    sops.secrets."searxng-secret-key" = {
      owner = "searx";
      group = "searx";
      mode = "0400";
    };

    sops.templates."searxng.env" = {
      owner = "searx";
      group = "searx";
      mode = "0400";
      content = ''
        SEARXNG_SECRET=${config.sops.placeholder."searxng-secret-key"}
      '';
    };

    services.searx = {
      enable = true;
      package = pkgs.searxng;
      redisCreateLocally = true;

      # Keep the instance private to the machine by default.
      # If you want LAN access later, change bind_address to "0.0.0.0"
      # and set openFirewall = true.
      openFirewall = false;

      environmentFile = config.sops.templates."searxng.env".path;

      settings = {
        general = {
          instance_name = "V3X Search";
          donation_url = false;
          contact_url = false;
          privacypolicy_url = false;
          enable_metrics = false;
        };
        ui = {
          static_use_hash = true;
          default_locale = "en";
          query_in_title = true;
          infinite_Scroll = false;
          center_alignment = true;
          default_theme = "simple";
          hotkeys = "vim";
        };
        search = {
          safe_Search = 2;
          autocomplete_min = 2;
          autocomplete = "duckduckgo";
          ban_time_on_fail = 5;
          max_ban_time_on_fail = 120;
        };
        # Outgoing requests
        outgoing = {
          request_timeout = 5.0;
          max_request_timeout = 15.0;
          pool_connections = 100;
          pool_maxsize = 15;
          enable_http2 = true;
        };
        # Enabled plugins
        enabled_plugins = [
          "Basic Calculator"
          "Hash plugin"
          "Tor check plugin"
          "Open Access DOI rewrite"
          "Hostnames plugin"
          "Unit converter plugin"
          "Tracker URL remover"
        ];
        server = {
          bind_address = "127.0.0.1";
          port = 8888;
          # inform searxng it should read env var
          secret_key = config.sops.secrets."searxng-secret-key".path;
        };
        engines = lib.mapAttrsToList (name: value: {inherit name;} // value) {
          "duckduckgo".disabled = true;
          "brave".disabled = true;
          "bing".disabled = false;
          "mojeek".disabled = true;
          "mwmbl".disabled = false;
          "mwmbl".weight = 0.4;
          "qwant".disabled = true;
          "crowdview".disabled = false;
          "crowdview".weight = 0.5;
          "curlie".disabled = true;
          "ddg definitions".disabled = false;
          "ddg definitions".weight = 2;
          "wikibooks".disabled = false;
          "wikidata".disabled = false;
          "wikiquote".disabled = true;
          "wikisource".disabled = true;
          "wikispecies".disabled = false;
          "wikispecies".weight = 0.5;
          "wikiversity".disabled = false;
          "wikiversity".weight = 0.5;
          "wikivoyage".disabled = false;
          "wikivoyage".weight = 0.5;
          "currency".disabled = true;
          "dictzone".disabled = true;
          "lingva".disabled = true;
          "bing images".disabled = false;
          "brave.images".disabled = true;
          "duckduckgo images".disabled = true;
          "google images".disabled = false;
          "qwant images".disabled = true;
          "1x".disabled = true;
          "artic".disabled = false;
          "deviantart".disabled = false;
          "flickr".disabled = true;
          "imgur".disabled = false;
          "library of congress".disabled = false;
          "material icons".disabled = true;
          "material icons".weight = 0.2;
          "openverse".disabled = false;
          "pinterest".disabled = true;
          "svgrepo".disabled = false;
          "unsplash".disabled = false;
          "wallhaven".disabled = false;
          "wikicommons.images".disabled = false;
          "yacy images".disabled = true;
          "bing videos".disabled = false;
          "brave.videos".disabled = true;
          "duckduckgo videos".disabled = true;
          "google videos".disabled = false;
          "qwant videos".disabled = false;
          "dailymotion".disabled = true;
          "google play movies".disabled = true;
          "invidious".disabled = true;
          "odysee".disabled = true;
          "peertube".disabled = false;
          "piped".disabled = true;
          "rumble".disabled = false;
          "sepiasearch".disabled = false;
          "vimeo".disabled = true;
          "youtube".disabled = false;
          "brave.news".disabled = true;
          "google news".disabled = true;
        };
      };
    };
  };
}
