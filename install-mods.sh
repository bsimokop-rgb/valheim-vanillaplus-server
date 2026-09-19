#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$ROOT_DIR/valheim/server"
PLUGINS_DIR="$SERVER_DIR/BepInEx/plugins"
CONFIG_DIR="$SERVER_DIR/BepInEx/config"
TMP_DIR="$ROOT_DIR/tmp/mod-install"

if [ ! -d "$SERVER_DIR/BepInEx" ]; then
  echo "ERROR: Valheim server runtime is not initialized yet."
  echo "Run: docker compose up"
  echo "Wait until the server installs, then stop it with Ctrl+C and run this script again."
  exit 1
fi

mkdir -p "$PLUGINS_DIR" "$CONFIG_DIR" "$TMP_DIR"

# Remove incompatible plugin bundled by the Docker image
rm -f "$PLUGINS_DIR/ServerDevcommands.dll"

cd "$TMP_DIR"

echo "== Updating BepInExPack to 5.4.2350 =="

curl -L \
  "https://gcdn.thunderstore.io/live/repository/packages/denikson-BepInExPack_Valheim-5.4.2350.zip" \
  -o BepInEx.zip

rm -rf bepinex
mkdir bepinex
unzip -q BepInEx.zip -d bepinex

BEP_SRC="$TMP_DIR/bepinex/BepInExPack_Valheim"

rm -rf "$SERVER_DIR/BepInEx/core" "$SERVER_DIR/doorstop_libs"

cp -R "$BEP_SRC/BepInEx/core" "$SERVER_DIR/BepInEx/core"
cp -R "$BEP_SRC/doorstop_libs" "$SERVER_DIR/doorstop_libs"
cp "$BEP_SRC/doorstop_config.ini" "$SERVER_DIR/doorstop_config.ini"
cp "$BEP_SRC/start_server_bepinex.sh" "$SERVER_DIR/start_server_bepinex.sh"
cp "$BEP_SRC/.doorstop_version" "$SERVER_DIR/.doorstop_version"
chmod +x "$SERVER_DIR/start_server_bepinex.sh"

echo "== Installing Jotunn 2.30.1 =="

curl -L \
  "https://gcdn.thunderstore.io/live/repository/packages/ValheimModding-Jotunn-2.30.1.zip" \
  -o Jotunn.zip

unzip -p Jotunn.zip 'plugins*Jotunn.dll' \
  > "$PLUGINS_DIR/Jotunn.dll"

echo "== Installing PlantEverything 1.21.2 =="

curl -L \
  "https://gcdn.thunderstore.io/live/repository/packages/Advize-PlantEverything-1.21.2.zip" \
  -o PlantEverything.zip

unzip -p PlantEverything.zip Advize_PlantEverything.dll \
  > "$PLUGINS_DIR/Advize_PlantEverything.dll"

echo "== Installing Seasonality 3.8.3 =="

curl -L \
  "https://gcdn.thunderstore.io/live/repository/packages/RustyMods-Seasonality-3.8.3.zip" \
  -o Seasonality.zip

unzip -p Seasonality.zip Seasonality.dll \
  > "$PLUGINS_DIR/Seasonality.dll"

unzip -qo Seasonality.zip 'config/Seasonality/*' \
  -d "$SERVER_DIR/BepInEx"

echo "== Installing YamlDotNet 16.3.1 =="

curl -L \
  "https://gcdn.thunderstore.io/live/repository/packages/ValheimModding-YamlDotNet-16.3.1.zip" \
  -o YamlDotNet.zip

unzip -p YamlDotNet.zip plugins/YamlDotNet.dll \
  > "$PLUGINS_DIR/YamlDotNet.dll"

echo "== Installing RecyclePlus 1.3.3 =="

curl -L \
  "https://gcdn.thunderstore.io/live/repository/packages/TastyChickenLegs-RecyclePlus-1.3.3.zip" \
  -o RecyclePlus.zip

unzip -p RecyclePlus.zip RecyclePlus.dll \
  > "$PLUGINS_DIR/RecyclePlus.dll"

echo "== Installing Sailing 1.1.8 =="

curl -L \
  "https://gcdn.thunderstore.io/live/repository/packages/Smoothbrain-Sailing-1.1.8.zip" \
  -o Sailing.zip

unzip -p Sailing.zip Sailing.dll \
  > "$PLUGINS_DIR/Sailing.dll"

echo
echo "Server modpack installed successfully."
echo
echo "Installed server mods:"
echo "  Jotunn 2.30.1"
echo "  PlantEverything 1.21.2"
echo "  Seasonality 3.8.3"
echo "  YamlDotNet 16.3.1"
echo "  RecyclePlus 1.3.3"
echo "  Sailing 1.1.8"
echo
echo "Excluded intentionally:"
echo "  Groups"
echo "  InventorySlots"
echo "  TargetPortal"

rm -rf "$TMP_DIR"
