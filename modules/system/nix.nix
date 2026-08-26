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
          git -C /etc/nixos fetch origin "$1"
          git -C /etc/nixos checkout --force -B "$1" "origin/$1"
        else
          git -C /etc/nixos fetch origin master
          git -C /etc/nixos checkout --force -B master origin/master
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
    imports = [
      # inputs.nix-index-database.nixosModules.nix-index
      # inputs.attic.
    ];
    # programs.nix-index-database.comma.enable = true;

    nix.settings.experimental-features = ["nix-command" "flakes"];
    programs.nix-ld.enable = true;
    nixpkgs.config.allowUnfree = true;

    nix.settings = {
      trusted-substituters = [
        "http://v3x-teapot:8082/v3x"
      ];
      trusted-public-keys = ["v3x:KkXZj5H0cOzciurQuabgGocSsZjXZplwgqVWh8Va5s8="];
    };

    environment.systemPackages = with pkgs; [
      inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.attic
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
