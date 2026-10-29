_: {
  flake.nixosModules.ingestarrStatus = _: let
    statuspage = {
      key,
      name,
      url,
      icon,
    }: {
      inherit key name icon;
      kind = "statuspage";
      interval = "20m";
      statuspage = {inherit url;};
    };
  in {
    services.ingestarr = {
      settings.source = [
        (statuspage {
          key = "github-status";
          name = "GitHub status";
          url = "https://www.githubstatus.com";
          icon = "github";
        })
        (statuspage {
          key = "cloudflare-status";
          name = "Cloudflare status";
          url = "https://www.cloudflarestatus.com";
          icon = "cloudflare";
        })
        (statuspage {
          key = "claude-status";
          name = "Claude status";
          url = "https://status.claude.com";
          icon = "claude";
        })
        (statuspage {
          key = "openai-status";
          name = "OpenAI status";
          url = "https://status.openai.com";
          icon = "openai";
        })
      ];

      collections = [
        {
          name = "status";
          title = "Status";
          kinds = ["statuspage"];
        }
      ];
    };
  };
}
