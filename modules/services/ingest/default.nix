{inputs, ...}: let
  inherit (import ../../network/services.nix) services;
in {
  imports = [
    ./releases.nix
    ./security.nix
    ./status.nix
    ./news.nix
    ./lore.nix
    ./huggingface.nix
    ./containers.nix
    ./packages.nix
    ./papers.nix
    ./youtube.nix
    ./hog.nix
  ];

  flake.nixosModules.ingestarr = {
    self,
    config,
    ...
  }: {
    imports = [
      inputs.ingestarr.nixosModules.default
      self.nixosModules.ingestarrReleases
      self.nixosModules.ingestarrSecurity
      self.nixosModules.ingestarrStatus
      self.nixosModules.ingestarrNews
      self.nixosModules.ingestarrLore
      self.nixosModules.ingestarrHuggingface
      self.nixosModules.ingestarrContainers
      self.nixosModules.ingestarrPackages
      self.nixosModules.ingestarrPapers
      self.nixosModules.ingestarrYoutube
      self.nixosModules.ingestarrHog
    ];

    sops.secrets.ingestarr_oidc_client_secret.restartUnits = ["ingestarr.service"];

    # v3x.backup.paths = ["/var/lib/private/ingestarr"];

    services.ingestarr = {
      enable = true;
      host = config.v3x.address;
      port = 3100;

      auth = {
        issuer = "https://${services.auth.name}/oauth2/openid/ingestarr";
        baseUrl = "https://${services.ingestarr.name}";
        clientSecretFile = config.sops.secrets.ingestarr_oidc_client_secret.path;
        allowedGroups = ["ingestarr_users@${services.auth.name}"];
      };

      settings.daemon.contact = "luc@v3x.email";
    };

    systemd.services.ingestarr = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
      unitConfig.RequiresMountsFor = ["/var/lib/private/ingestarr"];
    };
  };
}
