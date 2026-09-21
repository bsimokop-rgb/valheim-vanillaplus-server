#!/bin/bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$ROOT_DIR" || exit 1

echo
echo "========================================"
echo " Valheim server startup"
echo "========================================"
echo

echo "Step 1/2: Checking server mods..."
echo

./update-mods.sh

UPDATE_EXIT=$?

if [ "$UPDATE_EXIT" -ne 0 ]; then
  echo
  echo "WARNING: Mod updater returned an error."
  echo "Existing working mod files were kept."
  echo
  echo "Starting server with currently installed mods..."
fi

echo
echo "========================================"
echo " Step 2/2: Starting Valheim server"
echo "========================================"
echo

# Keep macOS awake while the server is running.
# When the server stops, caffeinate stops automatically too.
exec caffeinate -i docker compose up