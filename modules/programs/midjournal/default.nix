{inputs, ...}: {
  flake.nixosModules.midjournal = {config, ...}: {
    imports = [
      inputs.midjournal.nixosModules.midjournal
    ];

    sops = {
      secrets = {
        midjournal_github_token = {
          owner = "luc";
          mode = "0400";
        };
      };
    };

    programs.midjournal = {
      enable = true;
      user = "luc";
      directory = "/home/luc/docs";
      rolloverHour = 4;
      github_token.file = config.sops.secrets.midjournal_github_token.path;
      # template = ./journal-template.md;
    };
  };
}
