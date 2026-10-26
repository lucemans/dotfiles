file=${VOXTYPE_VOCABULARY:-${XDG_CONFIG_HOME:-$HOME/.config}/voxtype/vocabulary.txt}
system=/etc/voxtype/vocabulary.txt

usage() {
  cat >&2 <<'EOF'
Usage: voxtype-vocab <command>

  add TERM...        bias recognition toward each TERM (a word or phrase)
  fix HEARD MEANT    rewrite HEARD as MEANT, and bias recognition toward MEANT
  remove TERM        drop the entry for TERM, or the fix for HEARD
  list               show the system and user entries
  edit               open the user file in $EDITOR
  path               print the user file path

Changes apply from the next recording.
EOF
  exit 2
}

die() {
  echo "voxtype-vocab: $1" >&2
  exit 2
}

# The file holds one entry per line, so an entry cannot contain a newline or
# the `=>` that separates a fix.
check() {
  [ -n "$1" ] || die "empty entry"
  case $1 in
    *'=>'* | *$'\n'*) die "'$1' cannot contain '=>' or a newline" ;;
  esac
}

ensure() {
  mkdir -p "$(dirname "$file")"
  touch "$file"
}

# Drop entries whose left-hand side equals $1, ignoring case.
drop() {
  local tmp
  tmp=$(mktemp)
  awk -v key="$1" '
    BEGIN { key = tolower(key) }
    {
      lhs = $0
      sub(/^[ \t]+/, "", lhs)
      sub(/[ \t]*=>.*/, "", lhs)
      sub(/[ \t]+$/, "", lhs)
      if (tolower(lhs) != key) print $0
    }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

[ $# -ge 1 ] || usage
command=$1
shift

case $command in
  add)
    [ $# -ge 1 ] || usage
    ensure
    for term in "$@"; do
      check "$term"
      drop "$term"
      printf '%s\n' "$term" >>"$file"
    done
    ;;
  fix)
    [ $# -eq 2 ] || usage
    check "$1"
    check "$2"
    ensure
    drop "$1"
    printf '%s => %s\n' "$1" "$2" >>"$file"
    ;;
  remove)
    [ $# -eq 1 ] || usage
    ensure
    drop "$1"
    ;;
  list)
    [ $# -eq 0 ] || usage
    if [ -f "$system" ]; then
      echo "# $system"
      cat "$system"
    fi
    if [ -f "$file" ]; then
      echo "# $file"
      cat "$file"
    fi
    ;;
  edit)
    [ $# -eq 0 ] || usage
    ensure
    exec "${EDITOR:-vi}" "$file"
    ;;
  path)
    [ $# -eq 0 ] || usage
    echo "$file"
    ;;
  *) usage ;;
esac
