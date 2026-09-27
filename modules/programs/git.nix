{
  flake.nixosModules.git = {pkgs, ...}: {
    programs.git = {
      enable = true;
      lfs.enable = true;
      config = {
        user = {
          name = "Luc";
          email = "luc@lucemans.nl";
        };
        init.defaultBranch = "master";
        core.excludesFile = "${pkgs.writeText "gitignore" ''
          .pnpm-store
          .tmp
        ''}";
      };
    };
  };
}
