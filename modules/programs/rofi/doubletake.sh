set -euo pipefail

PORT_RANGE="60000-60010"
STOP_LABEL="Stop current cast"

decode_avahi_name() {
  local value="$1"
  value="${value//\\032/ }"
  value="${value//\\040/(}"
  value="${value//\\041/)}"
  printf '%s' "$value"
}

discover_targets() {
  avahi-browse -rtp _airplay._tcp 2>/dev/null \
    | awk -F ';' '$1 == "=" && $3 == "IPv4" && $0 ~ /"model=AppleTV/ { print $4 ";" $8 }' \
    | sort -u \
    | while IFS=';' read -r name address; do
      [[ -n "$name" && -n "$address" ]] || continue
      printf '%s\t%s\n' "$(decode_avahi_name "$name")" "$address"
    done
}

if [[ $# -eq 0 ]]; then
  printf '%s\n' "$STOP_LABEL"
  discover_targets
  exit 0
fi

selection="$*"

if [[ "$selection" == "$STOP_LABEL" ]]; then
  pkill -f 'doubletake-git .* -target ' 2>/dev/null || true
  exit 0
fi

target="${selection##*$'\t'}"
name="${selection%%$'\t'*}"

if [[ -z "$target" || "$target" == "$selection" ]]; then
  exit 1
fi

pkill -f 'doubletake-git .* -target ' 2>/dev/null || true

# shellcheck disable=SC2016
setsid -f kitty \
  --title "Double Take - $name" \
  sh -lc 'doubletake-git -port-range "$1" -no-audio -target "$2"; printf "\nDouble Take exited. Press Enter to close..."; read -r _' \
  sh "$PORT_RANGE" "$target" \
  </dev/null >/dev/null 2>&1
