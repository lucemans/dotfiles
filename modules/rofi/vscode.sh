#!/usr/bin/env bash

DATABASES=(
  "$HOME/.config/Code/User/globalStorage/state.vscdb"
  "$HOME/.config/VSCodium/User/globalStorage/state.vscdb"
  "$HOME/.config/Cursor/User/globalStorage/state.vscdb"
)

if [[ -z "$@" ]]; then
  for db in "${DATABASES[@]}"; do
    [[ -f "$db" ]] || continue
    sqlite3 "$db" "SELECT value FROM ItemTable WHERE key='history.recentlyOpenedPathsList'" \
      | jq -r '.entries[]? | .folderUri // .workspace // empty' \
      | sed 's|^file://||'
  done | sort -u
else
  codium "$@"
fi
