#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$ROOT_DIR/valheim/server"
PLUGINS_DIR="$SERVER_DIR/BepInEx/plugins"
CONFIG_DIR="$SERVER_DIR/BepInEx/config"
TMP_DIR="$ROOT_DIR/tmp/mod-install"
VERSION_FILE="$ROOT_DIR/.mod-versions"

if [ ! -d "$SERVER_DIR/BepInEx" ]; then
  echo "ERROR: Valheim server runtime is not initialized yet."
  echo
  echo "Run:"
  echo "  docker compose up"
  echo
  echo "Wait until the server initializes, stop it with Ctrl+C,"
  echo "then run ./install-mods.sh again."
  exit 1
fi

mkdir -p "$PLUGINS_DIR" "$CONFIG_DIR" "$TMP_DIR"

# Remove obsolete / incompatible plugins from older versions of this pack.
rm -f "$PLUGINS_DIR/Sailing.dll"

install_dll() {
  local namespace="$1"
  local package="$2"
  local version="$3"
  local dll_name="$4"
  local output_name="$5"

  local archive="$TMP_DIR/${package}.zip"
  local url="https://gcdn.thunderstore.io/live/repository/packages/${namespace}-${package}-${version}.zip"

  echo "== Installing ${package} ${version} =="

  curl -fL "$url" -o "$archive"

  python3 - "$archive" "$dll_name" "$PLUGINS_DIR/$output_name" <<'PY'
import os
import sys
import zipfile
import shutil

archive, wanted_dll, destination = sys.argv[1:]

with zipfile.ZipFile(archive, "r") as z:
    bad_file = z.testzip()
    if bad_file:
        raise RuntimeError(f"Corrupted ZIP entry: {bad_file}")

    matches = []

    for info in z.infolist():
        normalized = info.filename.replace("\\", "/")
        if normalized.rstrip("/").split("/")[-1] == wanted_dll:
            matches.append(info)

    if not matches:
        raise RuntimeError(
            f"Could not find {wanted_dll} inside {os.path.basename(archive)}"
        )

    os.makedirs(os.path.dirname(destination), exist_ok=True)

    with z.open(matches[0]) as src, open(destination, "wb") as dst:
        shutil.copyfileobj(src, dst)

print(f"Installed: {destination}")
PY

  echo
}

echo
echo "========================================"
echo " Valheim Vanilla+ mod installer"
echo "========================================"
echo

echo "== Installing BepInExPack Valheim 5.4.2350 =="

curl -fL \
  "https://gcdn.thunderstore.io/live/repository/packages/denikson-BepInExPack_Valheim-5.4.2350.zip" \
  -o "$TMP_DIR/BepInEx.zip"

rm -rf "$TMP_DIR/bepinex"
mkdir -p "$TMP_DIR/bepinex"

unzip -q "$TMP_DIR/BepInEx.zip" -d "$TMP_DIR/bepinex"

BEP_SRC="$TMP_DIR/bepinex/BepInExPack_Valheim"

rm -rf "$SERVER_DIR/BepInEx/core" "$SERVER_DIR/doorstop_libs"

cp -R "$BEP_SRC/BepInEx/core" "$SERVER_DIR/BepInEx/core"
cp -R "$BEP_SRC/doorstop_libs" "$SERVER_DIR/doorstop_libs"
cp "$BEP_SRC/doorstop_config.ini" "$SERVER_DIR/doorstop_config.ini"
cp "$BEP_SRC/start_server_bepinex.sh" "$SERVER_DIR/start_server_bepinex.sh"
cp "$BEP_SRC/.doorstop_version" "$SERVER_DIR/.doorstop_version"

chmod +x "$SERVER_DIR/start_server_bepinex.sh"

echo

install_dll \
  "ValheimModding" \
  "Jotunn" \
  "2.30.2" \
  "Jotunn.dll" \
  "Jotunn.dll"

install_dll \
  "Advize" \
  "PlantEverything" \
  "1.21.2" \
  "Advize_PlantEverything.dll" \
  "Advize_PlantEverything.dll"

install_dll \
  "RustyMods" \
  "Seasonality" \
  "3.8.3" \
  "Seasonality.dll" \
  "Seasonality.dll"

echo "== Installing Seasonality configuration =="

python3 - "$TMP_DIR/Seasonality.zip" "$SERVER_DIR/BepInEx" <<'PY'
import os
import sys
import zipfile
import shutil

archive, destination_root = sys.argv[1:]

with zipfile.ZipFile(archive, "r") as z:
    for info in z.infolist():
        normalized = info.filename.replace("\\", "/")

        if not normalized.startswith("config/Seasonality/"):
            continue

        relative = normalized
        destination = os.path.join(destination_root, relative)

        if info.is_dir():
            os.makedirs(destination, exist_ok=True)
            continue

        os.makedirs(os.path.dirname(destination), exist_ok=True)

        with z.open(info) as src, open(destination, "wb") as dst:
            shutil.copyfileobj(src, dst)

print("Seasonality configuration installed.")
PY

echo

install_dll \
  "ValheimModding" \
  "YamlDotNet" \
  "16.3.1" \
  "YamlDotNet.dll" \
  "YamlDotNet.dll"

install_dll \
  "TastyChickenLegs" \
  "RecyclePlus" \
  "1.3.5" \
  "RecyclePlus.dll" \
  "RecyclePlus.dll"

install_dll \
  "JereKuusela" \
  "Server_devcommands" \
  "1.113.0" \
  "ServerDevcommands.dll" \
  "ServerDevcommands.dll"

cat > "$VERSION_FILE" <<'EOF'
Jotunn=2.30.2
PlantEverything=1.21.2
Seasonality=3.8.3
YamlDotNet=16.3.1
RecyclePlus=1.3.5
Server_devcommands=1.113.0
EOF

chmod +x "$ROOT_DIR/update-mods.sh" 2>/dev/null || true
chmod +x "$ROOT_DIR/start-server.sh" 2>/dev/null || true

rm -rf "$TMP_DIR"

echo
echo "========================================"
echo " Server modpack installed successfully"
echo "========================================"
echo
echo "Installed server mods:"
echo "  BepInExPack Valheim 5.4.2350"
echo "  Jotunn 2.30.2"
echo "  PlantEverything 1.21.2"
echo "  Seasonality 3.8.3"
echo "  YamlDotNet 16.3.1"
echo "  RecyclePlus 1.3.5"
echo "  Server_devcommands 1.113.0"
echo
echo "Intentionally excluded:"
echo "  Sailing"
echo "  Groups"
echo "  InventorySlots"
echo "  TargetPortal"
echo
echo "Future server starts:"
echo "  ./start-server.sh"
echo