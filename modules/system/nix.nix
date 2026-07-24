{inputs, ...}: {
  flake.nixosModules.nix = {pkgs, ...}: let
    update = pkgs.writeShellApplication {
      name = "update";
      runtimeInputs = [pkgs.git];
      text = ''
        if [ "$#" -gt 1 ]; then
          printf 'usage: update [branch]\n' >&2
          exit 2
        fi

        if [ "$#" -eq 1 ]; then
          git -C /etc/nixos checkout "$1"
          git -C /etc/nixos pull origin "$1"
        else
          git -C /etc/nixos pull origin master
        fi
      '';
    };
    upgrade = pkgs.writeShellApplication {
      name = "upgrade";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.nh
      ];
      text = ''
        nh os switch /etc/nixos -H "$(hostname)"
      '';
    };
  in {
    # imports = [
    #   inputs.nix-index-database.nixosModules.nix-index
    # ];
    # programs.nix-index-database.comma.enable = true;

    nix.settings.experimental-features = ["nix-command" "flakes"];
    programs.nix-ld.enable = true;
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      nil
      nixd
      statix
      alejandra
      manix
      nix-inspect
      nh
      update
      upgrade
    ];
  };
}
