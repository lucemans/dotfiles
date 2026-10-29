_: {
  flake.nixosModules.ingestarrHog = _: {
    services.ingestarr.settings.source = [
      {
        key = "hog-v3xlabs";
        name = "TruffleHog v3xlabs";
        kind = "trufflehog";
        interval = "48h";
        trufflehog.orgs = ["v3xlabs"];
      }
      {
        key = "hog-openlv";
        name = "TruffleHog openlv";
        kind = "trufflehog";
        interval = "48h";
        trufflehog.orgs = ["open-lavatory"];
      }
      {
        key = "hog-ensdomains";
        name = "TruffleHog ensdomains";
        kind = "trufflehog";
        interval = "48h";
        trufflehog.orgs = ["ensdomains"];
      }
    ];
    services.ingestarr.collections = [
      {
        name = "hog";
        title = "Hog Finds";
        kinds = ["trufflehog"];
      }
    ];
  };
}
