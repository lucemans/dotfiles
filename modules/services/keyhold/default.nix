{inputs, ...}: {
  flake.nixosModules.keyhold = {config, ...}: {
    imports = [
      inputs.koi.nixosModules.default
    ];

    # sops = {
    #   age.keyFile = "/home/luc/.config/sops/age/keys.txt";
    #   defaultSopsFile = ../../../secrets/secrets.sops.yaml;
    #   secrets = {
    #   };
    # };

    services.koi = {
      enable = true;
      # host = "127.0.0.1";
      # port = 7777;
    };
  };
}
