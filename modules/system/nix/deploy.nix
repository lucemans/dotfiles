{
  self,
  inputs,
  lib,
  ...
}: {
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
    self.nixosConfigurations;

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
    deployRs = inputs.deploy-rs.packages.${pkgs.stdenv.hostPlatform.system}.default;
    deploy = pkgs.writeShellApplication {
      name = "deploy";
      runtimeInputs = [pkgs.coreutils pkgs.inetutils pkgs.nix pkgs.fzf pkgs.jq];
      excludeShellChecks = ["SC2016"];
      text = ''
        usage() {
          cat <<'EOF'
        usage: deploy [--source PATH] [--build current|target] [HOST|PATH#HOST[.PROFILE]] [deploy-rs options] [-- nix build options]
               deploy --raw [deploy-rs arguments]

        The source defaults to /etc/nixos, from any directory.
        Enter uses the host's recommended builder; ctrl-b chooses a builder.
        Watch and Mission build here; Teapot and Mediabus build on target.
        Self-deployment uses nh. Use upgrade for the usual local switch.
        Wrapper options go before HOST; deploy-rs options go after it.
        Existing commands starting with deploy-rs flags pass through unchanged.
        --raw runs deploy-rs unchanged, including multi-target and file forms.
        EOF
        }

        passthrough=false
        case "''${1:-}" in
          --raw) shift; passthrough=true ;;
          --source | --build | -h | --help) ;;
          -*) passthrough=true ;;
        esac
        if $passthrough; then
          printf 'deploy: raw deploy-rs arguments:' >&2
          printf ' %q' "$@" >&2
          printf '\n' >&2
          exec ${deployRs}/bin/deploy "$@"
        fi

        source=/etc/nixos
        build=""
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --source | --build)
              if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                usage >&2
                exit 2
              fi
              case "$1" in
                --source) source="$2" ;;
                --build) build="$2" ;;
              esac
              shift 2
              ;;
            -h | --help) usage; exit 0 ;;
            -*) usage >&2; exit 2 ;;
            *) break ;;
          esac
        done
        if [ -n "$build" ] && [ "$build" != current ] && [ "$build" != target ]; then
          echo 'deploy: --build must be current or target' >&2
          exit 2
        fi

        host="''${1:-}"
        if [ "$#" -gt 0 ]; then shift; fi
        if [[ "$host" == *#* ]]; then
          source="''${host%%#*}"
          source="''${source:-/etc/nixos}"
          host="''${host#*#}"
        fi
        profile=""
        if [[ "$host" == *.* ]]; then
          profile="''${host#*.}"
          host="''${host%%.*}"
        fi
        if [ ! -f "$source/flake.nix" ]; then
          printf 'deploy: no flake.nix in %s\n' "$source" >&2
          exit 2
        fi
        source="$(realpath -- "$source")"
        caller="$(hostname)"
        nodes="$(nix eval --json --no-write-lock-file "$source#deploy.nodes" --apply '
          nodes: builtins.mapAttrs (name: node: {
            inherit (node) hostname;
            build = if builtins.elem name ["v3x-teapot" "v3x-mediabus"] then "target" else "current";
          }) nodes')"

        pick() {
          fzf --ansi --delimiter='\t' --with-nth=2 --accept-nth=1 \
            --layout=reverse --cycle --height=~60% --border=rounded --border-label=" $1 " \
            --info=inline-right --pointer='▌' --prompt='  ' \
            --color=fg:-1,bg:-1,hl:#bd93f9,fg+:#f8f8f2:regular,bg+:#3a3c4e,hl+:#ff79c6 \
            --color=border:#44475a,label:#6272a4,prompt:#8be9fd,pointer:#ff79c6,info:#6272a4 \
            "''${@:2}"
        }

        if [ -z "$host" ]; then
          if [ ! -t 0 ] || [ ! -t 2 ]; then
            usage >&2
            exit 2
          fi
          rows="$(jq -r --arg caller "$caller" --arg build "$build" '
            to_entries | .[]
            | (if .value.hostname == $caller then "local nh switch"
               else "build on " + (if $build == "" then .value.build else $build end) end) as $label
            | "\(.key)\t\u001b[38;2;139;233;253m\(.key)\u001b[0m  \u001b[2m\($label)\u001b[0m"
          ' <<<"$nodes")"
          picked="$(printf '%s\n' "$rows" | pick 'deploy host' \
            --header='enter deploy / ctrl-b choose builder / esc cancel' --expect=ctrl-b)" || exit 130
          key="''${picked%%$'\n'*}"
          host="''${picked##*$'\n'}"
          if [ "$key" = ctrl-b ]; then
            build="$(printf 'current\tcurrent machine (%s)\ntarget\ttarget machine\n' "$caller" | pick "builder for $host")" || exit 130
            case "$build" in current | target) ;; *) exit 130 ;; esac
          fi
        fi
        if [ -z "$host" ] || ! jq -e --arg host "$host" 'has($host)' <<<"$nodes" >/dev/null; then
          printf 'deploy: unknown host %s\n' "$host" >&2
          exit 2
        fi
        destination="$(jq -r --arg host "$host" '.[$host].hostname' <<<"$nodes")"
        build="''${build:-$(jq -r --arg host "$host" '.[$host].build' <<<"$nodes")}"
        deploy_args=()
        while [ "$#" -gt 0 ] && [ "$1" != -- ]; do
          case "$1" in
            --remote-build) build=target ;;
            --targets | --targets=* | --file | --file=* | -f | --hostname | --hostname=*)
              echo 'deploy: use --raw for deploy-rs target-routing options' >&2
              exit 2
              ;;
            *) deploy_args+=("$1") ;;
          esac
          shift
        done
        if [ "''${1:-}" = -- ]; then shift; fi
        if [ "$destination" = "$caller" ]; then
          if [ "''${#deploy_args[@]}" -gt 0 ] || { [ -n "$profile" ] && [ "$profile" != system ]; }; then
            echo 'deploy: local nh switch accepts Nix build arguments after --; use --raw for deploy-rs options' >&2
            exit 2
          fi
          printf 'deploy: %s\n  source %s\n  build on current machine, local nh switch\n' "$destination" "$source" >&2
          exec ${pkgs.nh}/bin/nh os switch "$source" -H "$host" -- --no-write-lock-file --builders "" "$@"
        fi
        printf 'deploy: %s\n  source %s\n  build on %s machine\n' "$destination" "$source" "$build" >&2
        if [ "$build" = target ]; then deploy_args+=(--remote-build); fi
        exec ${deployRs}/bin/deploy "$source#$host''${profile:+.$profile}" "''${deploy_args[@]}" \
          -- --no-write-lock-file --builders "" "$@"
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
