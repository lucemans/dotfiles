#!/usr/bin/env bash

databasePaths=(
  "$HOME/.config/Code/User/globalStorage/state.vscdb"
  "$HOME/.config/VSCodium/User/globalStorage/state.vscdb"
  "$HOME/.config/Cursor/User/globalStorage/state.vscdb"
)

if (( $# == 0 )); then
  for databasePath in "${databasePaths[@]}"; do
    [[ -f "$databasePath" ]] || continue
    sqlite3 "$databasePath" "SELECT value FROM ItemTable WHERE key='history.recentlyOpenedPathsList'" \
      | jq -r '.entries[]? | (.folderUri // .workspace // empty) | sub("^file://"; "")'
  done | sort -u
else
  exec codium "$@"
fi
