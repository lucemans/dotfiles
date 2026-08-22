{inputs, ...}: {
  flake.nixosModules.gitgui = {
    config,
    pkgs,
    ...
  }: {
    # imports = [
    #   inputs.gitgui.nixosModules.default
    # ];

    # sops = {
    #   secrets = {
    #     auto_commit_llm_token = {
    #       owner = "luc";
    #       mode = "0400";
    #     };
    #   };
    # };

    # programs.gitgui = {
    #   enable = true;
    #   # user = "luc";
    #   # directory = "/home/luc/docs";
    # };
    environment.systemPackages = [inputs.gitgui.packages.${pkgs.stdenv.hostPlatform.system}.default];
  };
}
