{inputs, ...}: {
  flake.nixosModules.keyhold = {config, ...}: {
    imports = [
      inputs.koi.nixosModules.default
    ];

    services.koi = {
      enable = true;
      # host = "127.0.0.1";
      # port = 7777;
    };
  };
}
