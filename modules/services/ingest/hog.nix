_: {
  flake.nixosModules.ingestarrHog = _: let
    hog = key: name: org: {
      inherit key name;
      kind = "trufflehog";
      interval = "48h";
      trufflehog = {
        orgs = [org];
      };
    };
  in {
    services.ingestarr.settings.source = [
      (hog "hog-v3xlabs" "TruffleHog v3xlabs" "v3xlabs")
      (hog "hog-openlv" "TruffleHog openlv" "open-lavatory")
      (hog "hog-ensdomains" "TruffleHog ensdomains" "ensdomains")
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
