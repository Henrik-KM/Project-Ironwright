#!/usr/bin/env sh
set -eu
if command -v godot >/dev/null 2>&1; then
  GODOT=godot
elif command -v godot4 >/dev/null 2>&1; then
  GODOT=godot4
else
  echo "Godot 4.7.1 is required. Install it, then rerun this script." >&2
  exit 1
fi
exec "$GODOT" --path "$(dirname "$0")/game"
