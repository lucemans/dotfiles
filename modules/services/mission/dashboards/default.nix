{pkgs}: let
  overviewDashboard = pkgs.writeTextDir "overview.json" (builtins.readFile ./overview.json);
  homelabDashboard = pkgs.writeTextDir "homelab.json" (builtins.toJSON (import ./homelab-dashboard.nix));
  indexerPriceDashboard = pkgs.writeTextDir "indexer-prices.json" (builtins.toJSON (import ./indexer-price-dashboard.nix));
in
  pkgs.symlinkJoin {
    name = "mission-dashboards";
    paths = [
      overviewDashboard
      homelabDashboard
      indexerPriceDashboard
    ];
  }
