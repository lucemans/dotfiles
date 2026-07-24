{pkgs}: let
  homelabDashboard = pkgs.writeTextDir "homelab.json" (builtins.toJSON (import ./homelab-dashboard.nix));
in
  pkgs.symlinkJoin {
    name = "mission-dashboards";
    paths = [
      ./overview.json
      homelabDashboard
    ];
  }
