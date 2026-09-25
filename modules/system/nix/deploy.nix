{
  self,
  inputs,
  lib,
  ...
}: {
  # fighter builds and deploys; it switches itself with `upgrade`.
  flake.deploy.nodes =
    lib.mapAttrs (name: nixos: {
      hostname = name;
      sshUser = "luc";
      user = "root";
      # deploy-rs opens the activation and its confirmation waiter at the same
      # time; without a shared master they race for the key passphrase prompt.
      sshOpts = [
        "-o"
        "ControlMaster=auto"
        "-o"
        "ControlPath=~/.ssh/cm-%C"
        "-o"
        "ControlPersist=120"
      ];
      profiles.system.path =
        inputs.deploy-rs.lib.${nixos.pkgs.stdenv.hostPlatform.system}.activate.nixos nixos;
    })
    (removeAttrs self.nixosConfigurations ["v3x-fighter"]);

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
    deploy = inputs.deploy-rs.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in {
    environment.systemPackages = [
      update
      upgrade
      deploy
    ];
  };
}
