{
  flake.nixosModules.teapotMattermost = {
    config,
    lib,
    pkgs,
    inputs,
    ...
  }: {
    nixpkgs.config.allowUnfree = true;

    networking.firewall.allowedTCPPorts = [
      8065
    ];

    environment.systemPackages = with pkgs; [
      mattermost
    ];

    services.mattermost = {
      enable = true;
      siteUrl = "https://mm.v3x.sh";
      host = "0.0.0.0";
      port = 8065;
    };
  };
}
