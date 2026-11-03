_: {
  flake.nixosModules.ingestarrSecurity = _: {
    services.ingestarr = {
      settings.source = [
        {
          key = "nixos-lifecycle";
          name = "NixOS lifecycle";
          kind = "endoflife";
          icon = "nixos";
          endoflife.product = "nixos";
        }
        {
          key = "linux-lifecycle";
          name = "Linux lifecycle";
          kind = "endoflife";
          icon = "linux";
          endoflife.product = "linux";
        }
        {
          key = "postgresql-lifecycle";
          name = "PostgreSQL 15 lifecycle";
          kind = "endoflife";
          icon = "postgresql";
          endoflife = {
            product = "postgresql";
            cycles = ["15"];
          };
        }
        {
          key = "cisa-kev";
          name = "CISA exploited vulnerabilities";
          kind = "cisa-kev";
        }
        {
          key = "zero-wire";
          name = "Cloudflare Zero Wire";
          kind = "rss";
          icon = "cloudflare";
          rss.url = "https://radar.cloudflare.com/security/zero-wire/rss";
        }
      ];

      collections = [
        {
          name = "security";
          title = "Security";
          sources = ["cisa-kev" "zero-wire" "nixos-announce" "nixos-lifecycle" "postgresql-lifecycle" "linux-lifecycle"];
        }
      ];
    };
  };
}
