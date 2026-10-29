_: {
  flake.nixosModules.ingestarrNews = _: {
    services.ingestarr = {
      settings.source = [
        {
          key = "hacker-news";
          name = "Hacker News";
          kind = "hackernews";
          icon = "hacker-news";
          interval = "30m";
          hackernews = {
            list = "top";
            top_n = 30;
            min_points = 250;
          };
        }
        {
          key = "ethereum-blog";
          name = "Ethereum Blog";
          kind = "rss";
          rss.url = "https://blog.ethereum.org/en/feed.xml";
        }
        {
          key = "ens-blog";
          name = "ENS Blog";
          kind = "rss";
          rss.url = "https://ens.domains/blog/rss.xml";
        }
        {
          key = "nixos-announce";
          name = "NixOS announcements";
          kind = "rss";
          icon = "nixos";
          rss.url = "https://discourse.nixos.org/c/announcements/8.rss";
        }
        {
          key = "twir";
          name = "This Week in Rust";
          kind = "rss";
          icon = "rust";
          rss.url = "https://this-week-in-rust.org/rss.xml";
        }
        {
          key = "nos";
          name = "NOS Nieuws";
          kind = "rss";
          rss.url = "https://feeds.nos.nl/nosnieuwsalgemeen";
        }
        {
          key = "nu";
          name = "NU.nl";
          kind = "rss";
          rss.url = "https://www.nu.nl/rss/Algemeen";
        }
      ];

      collections = [
        {
          name = "news";
          title = "News";
          sources = ["hacker-news" "twir" "nos" "nu" "ethereum-blog"];
        }
      ];
    };
  };
}
