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

        branch="''${1:-master}"
        cd /etc/nixos

        confirm() {
          printf '%s Continue? [y/N] ' "$1" >&2
          read -r answer
          [ "$answer" = "y" ]
        }

        if [ -n "$(git status --porcelain)" ]; then
          git status --short >&2
          git diff --stat >&2
          confirm "update: the forced checkout discards these local changes." || exit 1
        fi

        git fetch origin "$branch"

        if [ -n "$(git log --oneline "origin/$branch..HEAD")" ]; then
          git log --oneline "origin/$branch..HEAD" >&2
          confirm "update: these local commits are not on origin/$branch." || exit 1
        fi

        git checkout --force -B "$branch" "origin/$branch"
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
      excludeShellChecks = ["SC2029"];

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
        out="$(
          nix build \
            "/etc/nixos#nixosConfigurations.$host.config.system.build.toplevel" \
            --no-link \
            --print-out-paths
        )"

        echo "==> Pushing $out to Attic"
        attic push v3x:v3x "$out"

        echo "==> copying to $host"
        nix copy --to "ssh://$host" --substitute-on-destination "$out"

        echo "==> Activating"
        ssh "$host" \
          "sudo nix-env -p /nix/var/nix/profiles/system --set '$out' && \
           sudo '$out/bin/switch-to-configuration' switch"
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
