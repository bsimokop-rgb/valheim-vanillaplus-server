#!/bin/bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$ROOT_DIR/valheim/server"
PLUGINS_DIR="$SERVER_DIR/BepInEx/plugins"

STATE_FILE="$ROOT_DIR/.mod-versions"
BACKUP_ROOT="$ROOT_DIR/mod-backups"

RUN_TS="$(date '+%Y%m%d-%H%M%S')"
TMP_ROOT="$(mktemp -d)"

UPDATED_MODS=""
FAILED_MODS=""
OUTDATED_MODS=""

CHECKED_COUNT=0
UPDATED_COUNT=0
FAILED_COUNT=0
OUTDATED_COUNT=0

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT

echo
echo "========================================"
echo " Valheim server mod update check"
echo "========================================"
echo

# ==================================================
# Prerequisites
# ==================================================

for cmd in curl python3 find grep cp mv docker; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' was not found."
    exit 1
  fi
done

if [ ! -d "$PLUGINS_DIR" ]; then
  echo "ERROR: BepInEx plugins directory does not exist:"
  echo "$PLUGINS_DIR"
  exit 1
fi

mkdir -p "$BACKUP_ROOT"

# ==================================================
# Safety: never update DLLs while server is running
# ==================================================

cd "$ROOT_DIR" || exit 1

RUNNING_CONTAINER="$(
  docker compose ps \
    --status running \
    -q valheim \
    2>/dev/null
)"

if [ -n "$RUNNING_CONTAINER" ]; then
  echo "ERROR: Valheim server is currently running."
  echo
  echo "Stop it before updating mods:"
  echo "  Ctrl+C"
  echo
  echo "No files were changed."
  exit 1
fi

# ==================================================
# Initial known versions
#
# This is only created if .mod-versions does not
# already exist. Existing state is preserved.
# ==================================================

if [ ! -f "$STATE_FILE" ]; then
  cat > "$STATE_FILE" <<'EOF'
Jotunn=2.30.1
PlantEverything=1.21.2
Seasonality=3.8.3
YamlDotNet=16.3.1
RecyclePlus=1.3.5
Server_devcommands=1.113.0
EOF
fi

# ==================================================
# State helpers
# ==================================================

get_installed_version() {
  local package="$1"

  grep "^${package}=" "$STATE_FILE" 2>/dev/null \
    | tail -1 \
    | cut -d= -f2-
}

set_installed_version() {
  local package="$1"
  local version="$2"
  local tmp_state="$STATE_FILE.tmp"

  grep -v "^${package}=" "$STATE_FILE" \
    > "$tmp_state" 2>/dev/null || true

  echo "${package}=${version}" >> "$tmp_state"

  mv "$tmp_state" "$STATE_FILE"
}

compare_versions() {
  python3 - "$1" "$2" <<'PY'
import sys

def parse(version):
    try:
        return tuple(
            int(part)
            for part in version.strip().lstrip("v").split(".")
        )
    except Exception:
        return ()

current = parse(sys.argv[1])
latest = parse(sys.argv[2])

if not current or not latest:
    print("unknown")
elif current < latest:
    print("older")
elif current > latest:
    print("newer")
else:
    print("same")
PY
}

# ==================================================
# Thunderstore version check
# ==================================================

get_latest_version() {
  local namespace="$1"
  local package="$2"

  local api_url
  local metadata

  api_url="https://thunderstore.io/api/experimental/package/${namespace}/${package}/"

  if ! metadata="$(
    curl -fsSL \
      --retry 3 \
      --retry-delay 2 \
      --connect-timeout 15 \
      -H "accept: application/json" \
      "$api_url" 2>/dev/null
  )"; then
    return 1
  fi

  printf '%s' "$metadata" |
    python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)

    version = data["latest"]["version_number"]

    if not version:
        raise ValueError("Empty version")

    print(version)

except Exception:
    sys.exit(1)
'
}

# ==================================================
# ZIP extraction
#
# Uses Python instead of macOS unzip.
# Handles both:
#
#   folder/file.dll
#   folder\file.dll
#
# inside Thunderstore packages.
# ==================================================

extract_dll_from_zip() {
  local zip_file="$1"
  local dll_name="$2"
  local output_file="$3"

  python3 - "$zip_file" "$dll_name" "$output_file" <<'PY'
import os
import sys
import zipfile

zip_path = sys.argv[1]
wanted_dll = sys.argv[2].lower()
output_path = sys.argv[3]

try:
    with zipfile.ZipFile(zip_path, "r") as archive:
        bad_file = archive.testzip()

        if bad_file is not None:
            print(
                f"Corrupted ZIP entry: {bad_file}",
                file=sys.stderr
            )
            sys.exit(2)

        match = None

        for original_name in archive.namelist():
            normalized = original_name.replace("\\", "/")
            basename = normalized.rsplit("/", 1)[-1]

            if basename.lower() == wanted_dll:
                match = original_name
                break

        if match is None:
            print(
                f"{wanted_dll} not found in archive",
                file=sys.stderr
            )
            sys.exit(3)

        data = archive.read(match)

        if not data:
            print(
                "DLL inside archive is empty",
                file=sys.stderr
            )
            sys.exit(4)

        os.makedirs(
            os.path.dirname(output_path),
            exist_ok=True
        )

        with open(output_path, "wb") as handle:
            handle.write(data)

        print(
            "Found archive entry:",
            match
        )

        print(
            "Extracted:",
            output_path
        )

except zipfile.BadZipFile:
    print(
        "Invalid ZIP archive",
        file=sys.stderr
    )
    sys.exit(5)

except Exception as exc:
    print(
        f"ZIP extraction error: {exc}",
        file=sys.stderr
    )
    sys.exit(6)
PY
}

# ==================================================
# Update one mod
# ==================================================

update_mod() {
  local namespace="$1"
  local package="$2"
  local dll="$3"

  local latest
  local current
  local relation

  local download_url
  local mod_tmp
  local zip_file
  local staged_dll
  local destination
  local backup_dir

  CHECKED_COUNT=$((CHECKED_COUNT + 1))

  echo "----------------------------------------"
  echo "Checking $package..."

  # ----------------------------------------------
  # Get latest Thunderstore version
  # ----------------------------------------------

  if ! latest="$(
    get_latest_version \
      "$namespace" \
      "$package"
  )"; then

    echo "WARNING: Could not retrieve latest version."
    echo "Keeping currently installed version."

    FAILED_MODS="${FAILED_MODS}${package} (version check failed)\n"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    echo
    return 0
  fi

  current="$(
    get_installed_version \
      "$package"
  )"

  echo "Installed: ${current:-unknown}"
  echo "Latest:    $latest"

  # ----------------------------------------------
  # Compare
  # ----------------------------------------------

  if [ -n "$current" ]; then
    relation="$(
      compare_versions \
        "$current" \
        "$latest"
    )"

    if [ "$relation" = "same" ]; then
      echo "Status: up to date."
      echo
      return 0
    fi

    if [ "$relation" = "newer" ]; then
      echo "Status: local version is newer than Thunderstore."
      echo "Skipping downgrade."
      echo
      return 0
    fi
  else
    relation="unknown"
  fi

  OUTDATED_COUNT=$((OUTDATED_COUNT + 1))

  OUTDATED_MODS="${OUTDATED_MODS}${package}: ${current:-unknown} -> ${latest}\n"

  echo "Status: update available."

  # ----------------------------------------------
  # Canonical Thunderstore CDN URL
  # ----------------------------------------------

  download_url="https://gcdn.thunderstore.io/live/repository/packages/${namespace}-${package}-${latest}.zip"

  echo "Downloading:"
  echo "  $download_url"

  mod_tmp="$TMP_ROOT/$package"
  zip_file="$mod_tmp/package.zip"
  staged_dll="$mod_tmp/$dll"

  mkdir -p "$mod_tmp"

  # ----------------------------------------------
  # Download
  # ----------------------------------------------

  if ! curl -fL \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout 15 \
    "$download_url" \
    -o "$zip_file"; then

    echo "WARNING: Download failed."
    echo "Keeping old $dll."

    FAILED_MODS="${FAILED_MODS}${package} (download failed)\n"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    echo
    return 0
  fi

  if [ ! -s "$zip_file" ]; then
    echo "WARNING: Downloaded archive is empty."
    echo "Keeping old $dll."

    FAILED_MODS="${FAILED_MODS}${package} (empty archive)\n"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    echo
    return 0
  fi

  # ----------------------------------------------
  # Extract only required DLL
  # ----------------------------------------------

  echo "Extracting $dll..."

  if ! extract_dll_from_zip \
    "$zip_file" \
    "$dll" \
    "$staged_dll"; then

    echo "WARNING: Could not extract $dll."
    echo "Keeping old version."

    FAILED_MODS="${FAILED_MODS}${package} (DLL extraction failed)\n"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    echo
    return 0
  fi

  if [ ! -s "$staged_dll" ]; then
    echo "WARNING: Extracted DLL is empty."
    echo "Keeping old version."

    FAILED_MODS="${FAILED_MODS}${package} (empty DLL)\n"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    echo
    return 0
  fi

  destination="$PLUGINS_DIR/$dll"

  # ----------------------------------------------
  # Backup current DLL
  # ----------------------------------------------

  if [ -f "$destination" ]; then
    backup_dir="$BACKUP_ROOT/$RUN_TS/$package"

    mkdir -p "$backup_dir"

    if ! cp \
      "$destination" \
      "$backup_dir/$dll"; then

      echo "WARNING: Could not create backup."
      echo "Update aborted for safety."

      FAILED_MODS="${FAILED_MODS}${package} (backup failed)\n"
      FAILED_COUNT=$((FAILED_COUNT + 1))

      echo
      return 0
    fi

    echo "Backup:"
    echo "  $backup_dir/$dll"
  fi

  # ----------------------------------------------
  # Atomic replacement
  # ----------------------------------------------

  rm -f "${destination}.new"

  if ! cp \
    "$staged_dll" \
    "${destination}.new"; then

    echo "WARNING: Could not stage new DLL."

    rm -f "${destination}.new"

    FAILED_MODS="${FAILED_MODS}${package} (copy failed)\n"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    echo
    return 0
  fi

  if [ ! -s "${destination}.new" ]; then
    echo "WARNING: Staged DLL is empty."

    rm -f "${destination}.new"

    FAILED_MODS="${FAILED_MODS}${package} (empty staged DLL)\n"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    echo
    return 0
  fi

  if ! mv \
    "${destination}.new" \
    "$destination"; then

    echo "WARNING: Could not replace existing DLL."

    rm -f "${destination}.new"

    FAILED_MODS="${FAILED_MODS}${package} (replace failed)\n"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    echo
    return 0
  fi

  # ----------------------------------------------
  # State changes only after successful install
  # ----------------------------------------------

  set_installed_version \
    "$package" \
    "$latest"

  UPDATED_COUNT=$((UPDATED_COUNT + 1))

  UPDATED_MODS="${UPDATED_MODS}${package}: ${current:-unknown} -> ${latest}\n"

  echo
  echo "UPDATED:"
  echo "  $package ${current:-unknown} -> $latest"
  echo
}

# ==================================================
# SERVER MOD ALLOWLIST
# ==================================================

update_mod \
  "ValheimModding" \
  "Jotunn" \
  "Jotunn.dll"

update_mod \
  "Advize" \
  "PlantEverything" \
  "Advize_PlantEverything.dll"

update_mod \
  "RustyMods" \
  "Seasonality" \
  "Seasonality.dll"

update_mod \
  "ValheimModding" \
  "YamlDotNet" \
  "YamlDotNet.dll"

update_mod \
  "TastyChickenLegs" \
  "RecyclePlus" \
  "RecyclePlus.dll"

update_mod \
  "JereKuusela" \
  "Server_devcommands" \
  "ServerDevcommands.dll"

# ==================================================
# Summary
# ==================================================

echo
echo "========================================"
echo " Update check complete"
echo "========================================"
echo

echo "Checked:              $CHECKED_COUNT"
echo "Updates found:        $OUTDATED_COUNT"
echo "Successfully updated: $UPDATED_COUNT"
echo "Failed:               $FAILED_COUNT"

if [ -n "$UPDATED_MODS" ]; then
  echo
  echo "Updated:"
  printf "%b" "$UPDATED_MODS"
fi

if [ -n "$FAILED_MODS" ]; then
  echo
  echo "Warnings:"
  printf "%b" "$FAILED_MODS"

  echo
  echo "Existing DLLs were kept for failed updates."
fi

if \
  [ "$OUTDATED_COUNT" -eq 0 ] && \
  [ "$FAILED_COUNT" -eq 0 ]; then

  echo
  echo "All tracked server mods are up to date."
fi

if \
  [ "$OUTDATED_COUNT" -gt 0 ] && \
  [ "$UPDATED_COUNT" -eq "$OUTDATED_COUNT" ] && \
  [ "$FAILED_COUNT" -eq 0 ]; then

  echo
  echo "All available updates were installed successfully."
fi

if [ "$UPDATED_COUNT" -gt 0 ]; then
  echo
  echo "IMPORTANT:"
  echo "Players must use matching versions of server-synced mods."
fi

echo
echo "Installed version state:"
cat "$STATE_FILE"

echo