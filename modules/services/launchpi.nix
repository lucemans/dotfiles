{inputs, ...}: {
  flake.nixosModules.launchpi = {
    pkgs,
    config,
    lib,
    ...
  }: {
    # sops.age.keyFile = "/home/luc/.config/sops/age/keys.txt";
    # sops.defaultSopsFile = ../../secrets/secrets.sops.yaml;

    services.launchpi = {
      enable = true;
      openFirewall = false;

      # environmentFile = config.sops.templates."searxng.env".path;
    };
  };
}
