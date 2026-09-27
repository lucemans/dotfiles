{
  pkgs,
  lib,
  selfpkgs,
  herdr,
  harnesses,
  toolsets,
  secretPaths,
  envFile,
  worktreeBase,
}: let
  inherit (harnesses) claude opencode pi omp;
  # Shadow git, sops and sudo on PATH, so these safeguards from tripwire.nix
  # win over any tool that ships its own.
  safeguards = lib.makeBinPath [selfpkgs.agent-git selfpkgs.agent-prohibited];
  secrets = lib.concatMapStringsSep " " lib.escapeShellArg secretPaths;
  tools = [
    claude.package
    opencode.package
    selfpkgs.mcp-servers
    pi.package
    omp.package
    pkgs.bashInteractive
    pkgs.nix
    pkgs.alejandra
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gawk
    pkgs.ripgrep
    pkgs.fd
    pkgs.jq
    pkgs.curl
    pkgs.wget
    pkgs.python3
    pkgs.nodejs
    pkgs.pnpm
    pkgs.ncurses
    pkgs.wl-clipboard
    pkgs.ffmpeg
    pkgs.v4l-utils
  ];

  bash = "${pkgs.bashInteractive}/bin/bash";
  cacert = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  herdrRelay =
    pkgs.writers.writePython3Bin "herdr-relay" {flakeIgnore = ["E501"];}
    (builtins.readFile ./herdr-relay.py);

  # A toolset's servers become entries in each harness's MCP config, its
  # packages join PATH and its devices are bound into the sandbox.
  toolsManifest = pkgs.writeText "agent-toolsets.json" (builtins.toJSON {
    toolsets = builtins.listToAttrs (map (t:
      lib.nameValuePair t.name {
        inherit (t) servers devices;
        bin = lib.makeBinPath t.packages;
      })
    toolsets);
    configs = map (h: h.mcp) (lib.filter (h: h ? mcp) (lib.attrValues harnesses));
  });
in
  # Runs the given command in the sandbox around the project at $PWD.
  pkgs.writeShellApplication {
    name = "agent-sandbox";
    runtimeInputs = [pkgs.bubblewrap pkgs.coreutils pkgs.git pkgs.jq];
    # Single-quoted $names in the jq programs below are jq variables, not shell
    # expansions.
    excludeShellChecks = ["SC2016"];
    text = ''
      project="$(realpath "$PWD")"

      # The sandbox covers the primary checkout and every worktree of its repository,
      # so a session can /move between them. The git directory stays read-only:
      # worktrees and branches are created on the host, never by the agent.
      # Launching inside a linked worktree resolves the repository it belongs to,
      # because its .git file points at the primary checkout.
      primary="$project"
      gitdir=""
      if gitdir="$(git -C "$project" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
        primary="$(dirname "$gitdir")"
      fi

      # The primary checkout is bound after the home binds, so a repository at
      # $HOME or above it would hide them and expose all of $HOME.
      if [ "$primary" = / ] || [ "$primary" = "$HOME" ] || [ "''${HOME#"$primary"/}" != "$HOME" ]; then
        echo "agent: refusing to sandbox $project, its repository $primary contains $HOME" >&2
        exit 1
      fi

      # One base per repository, bound as a directory instead of per worktree, so a
      # worktree created mid-session appears without relaunching. ~/dev/wt itself is
      # never bound, so another project's worktrees, and those of a same-named
      # repository elsewhere, stay out of reach.
      worktrees="${worktreeBase}"
      mkdir -p "$worktrees"

      roots=(--bind "$primary" "$primary" --bind "$worktrees" "$worktrees")
      # A linked worktree outside the base, or a subdirectory launch, is bound as well.
      if [ "$project" != "$primary" ]; then
        roots+=(--bind "$project" "$project")
      fi
      if [ -n "$gitdir" ]; then
        roots+=(--ro-bind "$gitdir" "$gitdir")
      fi


      nixcache="$HOME/.local/state/agent/nix-cache"
      mkdir -p "$nixcache" "$HOME/.local/share/opencode" "$HOME/.local/state/opencode" \
        "$HOME/.cache/ms-playwright" "$HOME/.pi/agent/sessions" "$HOME/.omp/agent"

      # Herdr injects its API socket into pane processes, and that socket opens panes
      # on the host, outside this sandbox. The relay takes its place: it pins this
      # pane and forwards agent state reports only.
      herdr=()
      if [ "''${HERDR_ENV:-}" = 1 ] && [ -n "''${HERDR_PANE_ID:-}" ] && [ -n "''${HERDR_SOCKET_PATH:-}" ]; then
        relay="$XDG_RUNTIME_DIR/agent-herdr-$$.sock"
        "${herdrRelay}/bin/herdr-relay" "$HERDR_SOCKET_PATH" "$relay" "$HERDR_PANE_ID" \
          >>"$HOME/.local/state/agent/herdr-relay.log" 2>&1 &

        for _ in $(seq 50); do
          if [ -S "$relay" ]; then
            break
          fi
          sleep 0.1
        done

        if [ -S "$relay" ]; then
          herdr=(
            --bind "$relay" "$XDG_RUNTIME_DIR/herdr.sock"
            --setenv HERDR_ENV 1
            --setenv HERDR_PANE_ID "$HERDR_PANE_ID"
            --setenv HERDR_SOCKET_PATH "$XDG_RUNTIME_DIR/herdr.sock"
            --setenv HERDR_BIN_PATH "${herdr}/bin/herdr"
          )
        else
          echo "agent: herdr relay did not start, the pane will report no agent state" >&2
        fi
      fi

      # Only the current user and group, so the host account list stays out.
      exec 3<<<"$USER:x:$(id -u):$(id -g):$USER:$HOME:${bash}"
      exec 4<<<"$(id -gn):x:$(id -g):"

      # Every session has base. AGENT_TOOLSETS names the toolsets added to it.
      read -ra chosen <<<"base ''${AGENT_TOOLSETS:-}"
      toolpath="$(jq -r '[.toolsets[$ARGS.positional[]].bin | select(. != "")] | join(":")' ${toolsManifest} --args "''${chosen[@]}")"
      mapfile -t devices < <(jq -r '[.toolsets[$ARGS.positional[]].devices[]] | unique[]' ${toolsManifest} --args "''${chosen[@]}")
      servers="$(jq -c '[.toolsets[$ARGS.positional[]].servers[]] | unique' ${toolsManifest} --args "''${chosen[@]}")"

      # Each harness MCP config goes to bwrap through a descriptor, so a launch
      # leaves no file behind.
      configs=()
      mapfile -t paths < <(jq -r '.configs[].path' ${toolsManifest})
      for i in "''${!paths[@]}"; do
        path="''${paths[$i]}"
        case "$path" in
          /*) ;;
          *) path="$HOME/$path" ;;
        esac
        config="$(jq --argjson i "$i" --argjson servers "$servers" '
          .configs[$i] | {(.key): (.servers | with_entries(select(.key | IN($servers[]))))}
        ' ${toolsManifest})"
        exec {fd}<<<"$config"
        configs+=(--ro-bind-data "$fd" "$path")
      done

      args=(
        --die-with-parent --unshare-all --share-net --clearenv
        --dir /nix --ro-bind /nix/store /nix/store
        --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket
        --dir /etc
        --ro-bind /etc/nix/nix.conf /etc/nix/nix.conf
        --ro-bind /etc/nix/registry.json /etc/nix/registry.json
        --ro-bind /etc/resolv.conf /etc/resolv.conf
        # The v3x zone is served from networking.hosts, not from a resolver, so an
        # internal name is unreachable without this.
        --ro-bind /etc/hosts /etc/hosts
        --ro-bind-data 3 /etc/passwd
        --ro-bind-data 4 /etc/group
        --proc /proc --dev /dev --tmpfs /tmp
        --ro-bind "${bash}" /bin/sh
        --tmpfs "$HOME"
        --dir "$HOME/.pi"
        --dir "$HOME/.pi/agent"
        --ro-bind ${pi.models} "$HOME/.pi/agent/models.json"
        --ro-bind ${pi.settings} "$HOME/.pi/agent/settings.json"
        --bind "$HOME/.pi/agent/sessions" "$HOME/.pi/agent/sessions"
        --bind "$HOME/.omp" "$HOME/.omp"
        --ro-bind ${omp.models} "$HOME/.omp/agent/models.yml"
        --bind "$nixcache" "$HOME/.cache/nix"
        "''${roots[@]}"
        --chdir "$project"
        --setenv HOME "$HOME"
        --setenv USER "$USER"
        --setenv PATH "${safeguards}:${lib.makeBinPath tools}''${toolpath:+:$toolpath}"
        --setenv AGENT_TOOLSETS "''${AGENT_TOOLSETS:-}"
        --setenv PUPPETEER_EXECUTABLE_PATH "${selfpkgs.playwrightMcpChromium}/bin/chromium"
        --setenv TERM "''${TERM:-xterm}"
        --setenv COLORTERM "''${COLORTERM:-}"
        --setenv TERMINFO_DIRS "${pkgs.ncurses}/share/terminfo:${pkgs.kitty.terminfo}/share/terminfo"
        --setenv SSL_CERT_FILE "${cacert}"
        --setenv NIX_SSL_CERT_FILE "${cacert}"
        --setenv NIX_REMOTE daemon
        --setenv PI_SKIP_VERSION_CHECK 1
        --setenv PS1 'agent:\w\$ '
        --setenv AGENT_SANDBOX 1
        --setenv OMP_WORKTREE_DIR "$worktrees"

        --ro-bind /etc/claude-code/managed-settings.json /etc/claude-code/managed-settings.json
        --bind "$HOME/.claude" "$HOME/.claude"
        --ro-bind "$HOME/.claude/settings.json" "$HOME/.claude/settings.json"
        --ro-bind "$HOME/.claude/skills" "$HOME/.claude/skills"
        --ro-bind "$HOME/.claude/agents" "$HOME/.claude/agents"
        --setenv CLAUDE_CONFIG_DIR "$HOME/.claude"

        --ro-bind "$HOME/.config/opencode" "$HOME/.config/opencode"
        --bind "$HOME/.local/share/opencode" "$HOME/.local/share/opencode"
        --bind "$HOME/.local/state/opencode" "$HOME/.local/state/opencode"
        --ro-bind "$HOME/.config/plan-env-md/config" "$HOME/.config/plan-env-md/config"
        --setenv OPENCODE_DISABLE_CHANNEL_DB 1
        # OpenCode merges this over its global config. A bind over the global
        # file fails, because home-manager makes it a symlink into the store and
        # bwrap cannot follow that while it builds the sandbox root.
        --setenv OPENCODE_CONFIG "${opencode.mcp.path}"

        --dir "$XDG_RUNTIME_DIR"
        --bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
        --ro-bind /tmp/.X11-unix /tmp/.X11-unix
        --dev-bind /dev/dri /dev/dri
        --ro-bind /etc/fonts /etc/fonts
        --bind "$HOME/.cache/ms-playwright" "$HOME/.cache/ms-playwright"
        --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR"
        --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY"
        --setenv DISPLAY "$DISPLAY"
        --setenv XDG_SESSION_TYPE "$XDG_SESSION_TYPE"
        "''${herdr[@]}"
        "''${configs[@]}"
      )
      for device in "''${devices[@]}"; do
        if [ -e "$device" ]; then
          args+=(--dev-bind "$device" "$device")
        fi
      done

      # The webcam nodes are absent from the sandbox devtmpfs, and their numbering
      # follows what is plugged in, so bind the ones that exist at launch. Access
      # rests on the host video group, which survives the user namespace as an
      # unmapped supplementary gid.
      for device in /dev/video*; do
        if [ -e "$device" ]; then
          args+=(--dev-bind "$device" "$device")
        fi
      done

      # A rotating /run/secrets generation reports as a missing path, which bwrap only
      # says is an unreadable source. Name the secret instead.
      for secret in ${secrets}; do
        if [ ! -e "$secret" ]; then
          echo "agent: $secret is not available, has sops run on this host?" >&2
          exit 1
        fi
        args+=(--ro-bind "$secret" "$secret")
      done

      # Herdr sees bwrap as the pane process, never the harness inside it. The hint
      # names the screen manifest to evaluate; it stays on this process, because bwrap
      # clears the environment it passes on.
      case "$1" in
        omp | claude | opencode | pi) export HERDR_AGENT="$1" ;;
      esac

      # Sourced in the sandbox rather than passed with --setenv, which would publish
      # every value through bwrap's argv in /proc.
      command=(
        "${bash}" -c 'set -a; . "$1"; set +a; shift; exec "$@"'
        agent "${envFile}" "$@"
      )

      if grep -qs '^use flake' "$project/.envrc"; then
        command=(
          nix develop "$project" -c
          "${bash}" -c 'PATH=$1:$PATH; shift; exec "$@"' agent "${safeguards}"
          "''${command[@]}"
        )
      fi

      exec bwrap "''${args[@]}" -- "''${command[@]}"
    '';
  }
