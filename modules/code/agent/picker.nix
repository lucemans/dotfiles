{
  lib,
  harnesses,
}: let
  targets = lib.concatMap (harness: harness.profiles or [harness]) harnesses;
  tools = lib.concatMapStringsSep "|" (target: target.tool) targets;

  keyed = harness: map (profile: profile // {key = "${harness.label}/${profile.label}";}) harness.profiles;
  menu = map (harness: harness // {key = harness.label;}) harnesses;

  profiled = lib.filter (harness: harness ? profiles) menu;

  # Rows the picker can draw: the harness menu plus every profile submenu.
  rendered = menu ++ lib.concatMap keyed profiled;

  # Rows that resolve to a tool: leaf harnesses and profiles, never a harness
  # that only leads to a submenu.
  entries =
    lib.concatMap
    (harness:
      if harness ? profiles
      then keyed harness
      else [harness])
    menu;

  # One kitty image id per distinct logo, carried to the terminal as a 24-bit
  # foreground colour: r=1, b=index. fzf rewrites 8-bit colours into legacy SGR
  # codes and would corrupt the id, but it passes a truecolor triplet through
  # unchanged, including on the highlighted row.
  logos = lib.unique (map (entry: "${entry.logo}") rendered);
  index = logo: lib.lists.findFirstIndex (candidate: candidate == logo) 0 logos + 1;

  # Two cells of U+10EEEE, tagged (row 0, column 0) and (row 0, column 1) with
  # kitty's rowcolumn diacritics. Nix has no unicode escape, so the codepoints
  # arrive through JSON, U+10EEEE as its surrogate pair.
  cells = builtins.fromJSON ''"\udbfb\udeee\u0305\u0305\udbfb\udeee\u0305\u030d"'';

  mark = {
    image = entry: "\\033[38;2;1;0;${toString (index "${entry.logo}")}m${cells}\\033[39m";
    glyph = entry: "\\033[38;2;${entry.color}m${entry.glyph} \\033[0m";
  };

  width = group: lib.foldl' (accumulator: entry: lib.max accumulator (lib.stringLength entry.label)) 0 group;
  pad = size: text: text + lib.concatStrings (lib.genList (_: " ") (size - lib.stringLength text));

  row = kind: size: entry: "'${entry.key}\\t${mark.${kind} entry}  ${pad size entry.label}  \\033[2m${entry.blurb}\\033[0m'";
  rows = kind: group: lib.concatMapStringsSep " \\\n        " (row kind (width group)) group;

  stage = kind: group: key: ''
    ${kind}/${key})
      printf '%s\n' ${rows kind group}
      ;;'';

  stages =
    lib.concatMapStringsSep "\n"
    (kind:
      lib.concatMapStringsSep "\n" (line: line)
      ([(stage kind menu "")]
        ++ map (harness: stage kind (keyed harness) harness.label)
        profiled))
    ["image" "glyph"];

  transmits =
    lib.concatMapStringsSep "\n"
    (logo: "      icon ${toString (65536 + index logo)} ${logo}")
    logos;

  resolveEntries = lib.concatMapStringsSep " " (entry: "[${entry.key}]=${entry.tool}") entries;
in ''
  # A virtual placement holds the image; the rows only reference it, so fzf can
  # redraw and filter them like any other text. The terminator is written as
  # \134 so the format does not end on an escaped backslash, which the linter
  # reads as a quoting mistake.
  icon() {
    printf '\033_Ga=T,U=1,i=%s,f=100,t=f,c=2,r=1,q=2;%s\033\134' \
      "$1" "$(printf '%s' "$2" | base64 -w0)" >&2
  }

  pick() {
    local label="$1"
    shift
    choice="$(
      printf '%b\n' "$@" |
        fzf --ansi --delimiter='\t' --with-nth=2 --accept-nth=1 \
          --layout=reverse --cycle --height=~60% --border=rounded --border-label=" $label " \
          --info=inline-right --pointer='▌' --prompt='  ' \
          --color=fg:-1,bg:-1,hl:#bd93f9,fg+:-1:regular,bg+:#3a3c4e,hl+:#ff79c6 \
          --color=border:#44475a,label:#6272a4,prompt:#8be9fd,pointer:#ff79c6,info:#6272a4
    )" || exit 130
  }

  rows_for() {
    case "$marks/$1" in
    ${stages}
    esac
  }

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
      if [ -n "''${KITTY_WINDOW_ID:-}" ]; then
        marks=image
  ${transmits}
      else
        marks=glyph
      fi
      mapfile -t options < <(rows_for "")
      pick harness "''${options[@]}"
      key="$choice"
      mapfile -t options < <(rows_for "$key")
      if [ "''${#options[@]}" -gt 0 ]; then
        pick profile "''${options[@]}"
        key="$choice"
      fi
      tool="''${resolve[$key]}"
      printf '\n  agent %s%s\n\n' "$tool" "''${*:+ $*}" >&2
      ;;
  esac
''
