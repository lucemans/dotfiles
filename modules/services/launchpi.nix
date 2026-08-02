{inputs, ...}: {
  flake.nixosModules.launchpi = {
    pkgs,
    config,
    lib,
    ...
  }: {
    imports = [
      inputs.launchpi.nixosModules.default
    ];

    services.launchpi = {
      enable = true;
      # openFirewall = false;
      port = 7778;
    };
  };
}
