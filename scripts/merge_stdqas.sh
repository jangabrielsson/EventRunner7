#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/tests/stdQAs"
OUT_FILE="$SRC_DIR/stdQAs.lua"
TMP_FILE="$OUT_FILE.tmp"

{
  find "$SRC_DIR" -maxdepth 1 -type f -name '*.lua' \
    ! -name 'stdQAs.lua' \
    -print \
    | sort \
    | while IFS= read -r file; do
        base_name="$(basename "$file")"
        echo "-- BEGIN: $base_name"
        echo "do"
        # Strip Lua comments from merged content:
        # - remove block comments: --[[ ... ]]
        # - remove line comments starting with -- (including --%% headers)
        # Kept comments are only generated BEGIN/END markers.
        perl -0777 -pe 's/--\[\[[\s\S]*?\]\]//g' "$file" \
          | sed -E 's/[[:space:]]*--.*$//' \
          | sed -E '/^[[:space:]]*$/d'
        echo
        echo "end"
        echo "-- END: $base_name"
        echo
      done
} > "$TMP_FILE"

mv "$TMP_FILE" "$OUT_FILE"
echo "Wrote $OUT_FILE"
