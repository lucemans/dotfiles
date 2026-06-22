{inputs, ...}: {
  flake.nixosModules.firefly-iii = {
    pkgs,
    config,
    lib,
    ...
  }: {
    sops.age.keyFile = "/home/luc/.config/sops/age/keys.txt";
    sops.defaultSopsFile = ../secrets/secrets.sops.yaml;
    sops.secrets."firefly-iii-app-key" = {
      owner = "firefly-iii";
      group = "nginx";
      mode = "0400";
    };
    sops.secrets."firefly-iii-access-token" = {
      owner = "firefly-iii";
      group = "nginx";
      mode = "0400";
    };

    services.firefly-iii = {
      enable = true;
      enableNginx = true;
      virtualHost = "firefly.internal";
      settings = {
        APP_ENV = "production";
        APP_KEY_FILE = config.sops.secrets."firefly-iii-app-key".path;
        SITE_OWNER = "luc@lucemans.nl";
        APP_URL = "http://firefly.internal";
      };
    };

    services.firefly-iii-data-importer = {
      enable = true;
      enableNginx = true;
      virtualHost = "firefly-data.internal";
      settings = {
        FIREFLY_III_URL = "http://firefly.internal";
        FIREFLY_III_ACCESS_TOKEN_FILE = config.sops.secrets."firefly-iii-access-token".path;
      };
    };
  };
}
