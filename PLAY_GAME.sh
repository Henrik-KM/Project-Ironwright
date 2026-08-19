#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
python3 -m http.server 8000 --directory web &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT INT TERM
sleep 1
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open http://localhost:8000 >/dev/null 2>&1 || true
elif command -v open >/dev/null 2>&1; then
  open http://localhost:8000
fi
wait "$server_pid"
