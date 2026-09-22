{
  lib,
  harnesses,
}: let
  targets = lib.concatMap (harness: harness.profiles or [harness]) harnesses;
  tools = lib.concatMapStringsSep "|" (target: target.tool) targets;

  labels = lib.concatMapStringsSep " " (harness: harness.label) harnesses;

  profiled = lib.filter (harness: harness ? profiles) harnesses;
  profileEntries =
    lib.concatMapStringsSep " "
    (harness: ''[${harness.label}]="${lib.concatMapStringsSep " " (profile: profile.label) harness.profiles}"'')
    profiled;

  resolveEntries =
    lib.concatMapStringsSep " "
    (harness:
      if harness ? profiles
      then lib.concatMapStringsSep " " (profile: "[${harness.label}/${profile.label}]=${profile.tool}") harness.profiles
      else "[${harness.label}]=${harness.tool}")
    harnesses;
in ''
  pick() {
    local prompt="$1"
    shift
    local options=("$@")
    local index key
    {
      printf '\n  %s\n\n' "$prompt"
      for index in "''${!options[@]}"; do
        printf '    %d) %s\n' "$((index + 1))" "''${options[index]}"
      done
      printf '\n  > '
    } >&2
    while true; do
      IFS= read -rsn1 key || exit 130
      case "$key" in
        [1-9])
          if [ "$key" -le "''${#options[@]}" ]; then
            choice="''${options[$((key - 1))]}"
            printf '%s\n' "$choice" >&2
            return 0
          fi
          ;;
        q) printf 'cancelled\n' >&2; exit 130 ;;
      esac
    done
  }

  harnesses=(${labels})
  declare -A profiles=(${profileEntries})
  declare -A resolve=(${resolveEntries})

  # An unrecognised first argument means "ask me", not a usage error, so
  # `agent --resume <id>` picks a harness and forwards its arguments untouched.
  case "''${1:-}" in
    ${tools}) tool="$1"; shift ;;
    *)
      if [ ! -t 0 ] || [ ! -t 2 ]; then
        echo "usage: agent <${tools}> [args...]" >&2
        exit 2
      fi
      pick harness "''${harnesses[@]}"
      key="$choice"
      if [ -n "''${profiles[$key]:-}" ]; then
        read -ra options <<<"''${profiles[$key]}"
        pick profile "''${options[@]}"
        key="$key/$choice"
      fi
      tool="''${resolve[$key]}"
      printf '\n  agent %s%s\n\n' "$tool" "''${*:+ $*}" >&2
      ;;
  esac
''
