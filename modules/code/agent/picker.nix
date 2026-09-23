{
  pkgs,
  harnesses,
  sandbox,
}: let
  manifest = pkgs.writeText "agent-harnesses.json" (builtins.toJSON harnesses);
in
  pkgs.writeShellApplication {
    name = "agent";
    runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.fzf pkgs.gnused pkgs.jq];
    # Single-quoted $names in the jq programs below are jq variables, not shell
    # expansions.
    excludeShellChecks = ["SC2016"];
    text = ''
      project="$(realpath "$PWD")"
      if [ "$project" = "$HOME" ] || [ "$project" = / ]; then
        echo "agent: refusing to sandbox $project" >&2
        exit 1
      fi

      # Harness and profile data come from the manifest, which Nix writes from every
      # harness module's entry.
      harness=""
      key=""
      marks=""

      defs='
        def logos: [.[] | .logo, .profiles[]?.logo] | unique;
        def harness: .[] | select(.name == $harness);
        def entry: harness | if .profiles then .profiles[] | select("\($harness)/\(.name)" == $key) else . end;
      '

      # jq over the manifest, taking options first and the filter last as jq does.
      query() {
        jq --arg harness "$harness" --arg key "$key" --arg marks "$marks" "''${@:1:$#-1}" "$defs''${!#}" "${manifest}"
      }

      # Reads a jq list into the named array, NUL-separated so an argument may hold
      # any character.
      load() {
        mapfile -d ''' "$1" < <(query -j "$2"' | .[] | . + "\u0000"')
      }

      # Kitty draws a logo through a virtual placement, which the rows only
      # reference, so fzf can redraw and filter them like any other text. A row
      # carries its image id as a 24-bit foreground colour, r=1 and b=index: fzf
      # rewrites 8-bit colours into legacy SGR codes and would corrupt the id, but
      # passes a truecolor triplet through unchanged. The id is drawn as two cells of
      # U+10EEEE tagged (row 0, column 0) and (row 0, column 1) with kitty's
      # rowcolumn diacritics.
      rows() {
        query -r '
          logos as $logos
          | [if $harness == "" then .[] | . + {key: .name}
             else harness | .profiles[] | . + {key: "\($harness)/\(.name)"} end]
          | (map(.name | length) | max) as $width
          | .[]
          | .logo as $logo
          | (if $marks == "image"
             then "\u001b[38;2;1;0;\(($logos | index($logo)) + 1)m\udbfb\udeee\u0305\u0305\udbfb\udeee\u0305\u030d\u001b[39m"
             else "\u001b[38;2;\(.color)m\(.glyph) \u001b[0m" end) as $mark
          | "\(.key)\t\($mark)  \(.name)\(" " * ($width - (.name | length) + 2))\u001b[2m\(.blurb)\u001b[0m"'
      }

      # The terminator is written as \134 so the format does not end on an escaped
      # backslash, which the linter reads as a quoting mistake.
      ready_marks() {
        if [ -n "$marks" ]; then
          return
        fi
        marks=glyph
        # Herdr renders kitty placements for a kitty client but does not pass
        # KITTY_WINDOW_ID into its panes.
        if [ -n "''${KITTY_WINDOW_ID:-}" ] || [ "''${HERDR_ENV:-}" = 1 ]; then
          marks=image
          while IFS=$'\t' read -r id logo; do
            printf '\033_Ga=T,U=1,i=%s,f=100,t=f,c=2,r=1,q=2;%s\033\134' \
              "$id" "$(printf '%s' "$logo" | base64 -w0)" >&2
          done < <(query -r 'logos | to_entries[] | "\(.key + 65537)\t\(.value)"')
        fi
      }

      pick() {
        fzf --ansi --delimiter='\t' --with-nth=2 --accept-nth=1 \
          --layout=reverse --cycle --height=~60% --border=rounded --border-label=" $1 " \
          --info=inline-right --pointer='▌' --prompt='  ' \
          --color=fg:-1,bg:-1,hl:#bd93f9,fg+:-1:regular,bg+:#3a3c4e,hl+:#ff79c6 \
          --color=border:#44475a,label:#6272a4,prompt:#8be9fd,pointer:#ff79c6,info:#6272a4
      }

      # The proxy decides what exists: a model it cannot route must not be offered,
      # so the catalog is its model list rather than the upstream's.
      models() {
        curl -sS --fail --max-time 15 -H "Authorization: Bearer $(cat "$2")" "$1" |
          jq -r --arg prefix "$3" --arg qualify "$4" '
            [.data[].id]
            | map(select(startswith($prefix) and (contains("*") | not)))
            | sort
            | .[]
            | [$qualify + ., ltrimstr($prefix)]
            | @tsv
          '
      }

      # Any of these makes OMP load an existing session. An explicit --model would
      # then replace the model that session recorded, so none is passed.
      resuming() {
        local arg
        for arg in "$@"; do
          case "$arg" in
            --resume | --resume=* | -r | --session | --session=* | --continue | -c | --fork | --fork=*) return 0 ;;
          esac
        done
        return 1
      }

      # A session records every model it switched to, and each OMP profile starts on
      # its own default model, so the last default-role model names the profile that
      # owns the session. Resuming under that profile keeps its tiny, smol and slow
      # roles.
      omp_session_key() {
        local ref="" file="" model
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --resume=* | --session=*) ref="''${1#*=}" ;;
            --resume | -r | --session) ref="''${2:-}" ;;
          esac
          shift
        done
        if [ -z "$ref" ] || [ "''${ref#-}" != "$ref" ]; then
          return 1
        fi
        if [ -f "$ref" ]; then
          file="$ref"
        else
          for file in "$HOME"/.omp/agent/sessions/*/*_"$ref"*.jsonl; do
            if [ -f "$file" ]; then
              break
            fi
          done
        fi
        if [ ! -f "$file" ]; then
          return 1
        fi
        model="$(
          jq -rR 'fromjson? | select(.type == "model_change" and (.role // "default") == "default") | .model' "$file" |
            sed -n '$p'
        )"
        query -er --arg model "$model" '
          first(harness | .profiles[]
            | .catalog as $catalog
            | select(.modelRoles.default == $model
              or ($catalog != null and ($model | startswith($catalog.qualify + $catalog.prefix))))
            | "\($harness)/\(.name)")'
      }

      interactive=false
      if [ -t 0 ] && [ -t 2 ]; then
        interactive=true
      fi

      # An unrecognised first argument means "ask me", not a usage error, so
      # `agent --resume <id>` picks a harness and forwards its arguments untouched.
      harness="''${1:-}"
      if [ -n "$harness" ] && query -e 'any(.[]; .name == $harness)' >/dev/null; then
        shift
      else
        harness=""
        if ! $interactive; then
          echo "usage: agent [$(query -r '[.[].name] | join("|")')] [args...]" >&2
          exit 2
        fi
        ready_marks
        harness="$(rows | pick harness)" || exit 130
      fi

      key="$harness"
      if query -e 'harness | has("profiles")' >/dev/null; then
        if [ "$harness" = omp ] && session="$(omp_session_key "$@")"; then
          key="$session"
        elif $interactive; then
          ready_marks
          key="$(rows | pick "$harness")" || exit 130
        else
          # A harness run without a terminal gets its first profile.
          key="$(query -r 'harness | "\(.name)/\(.profiles[0].name)"')"
        fi
      fi

      start=()
      catalog=()
      if ! resuming "$@"; then
        load start 'entry | .start // []'
        load catalog 'entry | if .catalog then .catalog | [.url, .token, .prefix, .qualify] else [] end'
      fi

      # A profile whose model is chosen from a live catalog resolves it here, so a
      # fresh `agent omp` session on that profile asks too.
      if [ "''${#catalog[@]}" -gt 0 ]; then
        if ! $interactive; then
          echo "agent: $key picks its model interactively, so it needs a terminal" >&2
          exit 2
        fi
        mapfile -t options < <(models "''${catalog[@]}")
        if [ "''${#options[@]}" -eq 0 ]; then
          echo "agent: ''${catalog[0]} offers no ''${catalog[2]} models" >&2
          exit 1
        fi
        model="$(printf '%s\n' "''${options[@]}" | pick model)" || exit 130
        start=(--model "$model")
      fi

      if $interactive; then
        printf '\n  agent %s%s\n\n' "$key" "''${start[*]:+ ''${start[*]}}''${*:+ $*}" >&2
      fi

      command=()
      load command 'entry | .command'
      exec ${sandbox}/bin/agent-sandbox "''${command[@]}" "''${start[@]}" "$@"
    '';
  }
