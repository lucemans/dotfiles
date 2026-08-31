{inputs, ...}: {
  flake.nixosModules.rollout = {pkgs, ...}: let
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
    deploy = pkgs.writeShellApplication {
      name = "deploy";

      runtimeInputs = [
        inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.attic
        pkgs.openssh
        pkgs.nix
      ];

      text = ''
        if [ "$#" -ne 1 ]; then
          echo "usage: deploy <hostname>" >&2
          exit 2
        fi

        host="$1"

        echo "==> Building $host"
        built="$(
          nix build \
            "/etc/nixos#nixosConfigurations.$host.config.system.build.toplevel" \
            --no-link \
            --print-out-paths
        )"

        echo "==> Pushing $built to Attic"
        attic push v3x "\$built"

        echo "==> Activating on $host"
        ssh "$host" \
          "sudo nix-store --realise '\$built' &&
           sudo '\$built/bin/switch-to-configuration' switch"
      '';
    };
  in {
    environment.systemPackages = [
      update
      upgrade
      deploy
    ];
  };
}
