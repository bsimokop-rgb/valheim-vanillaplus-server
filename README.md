# Valheim Vanilla+ Dedicated Server

A reproducible Docker-based Valheim dedicated server with a lightweight, stability-focused Vanilla+ modpack.

This repository contains:

- Docker server configuration
- automatic server-side mod installation
- a ready-to-import Thunderstore client profile
- recommended client mod configuration
- save and backup configuration
- troubleshooting and recovery notes

It does **not** contain:

- world saves
- passwords
- player progress
- private server data
- public or local IP addresses

Each installation creates its own world and progression.

---

## Server Modpack

Tested server-side stack:

| Mod | Version |
| --- | --- |
| BepInExPack Valheim | 5.4.2350 |
| Jotunn | 2.30.1 |
| PlantEverything | 1.21.2 |
| Seasonality | 3.8.3 |
| YamlDotNet | 16.3.1 |
| RecyclePlus | 1.3.3 |
| Sailing | 1.1.8 |

### Intentionally excluded

These mods were tested but removed because of compatibility or stability problems with the current Valheim version:

| Mod | Version | Reason |
| --- | --- | --- |
| Groups | 1.2.10 | `MissingMethodException` / Chat & ConsoleCommand incompatibility |
| InventorySlots | 1.5.4 | instability during testing |
| TargetPortal | 1.2.3 | Harmony / API compatibility errors |

`ServerDevcommands.dll`, which may be bundled by the Docker image during initial setup, is automatically removed by `install-mods.sh` because the bundled version is incompatible with the current Valheim build.

---

## Recommended Client Mods

Players should use the same versions of all server-synced mods.

### Required / server-synced

- BepInExPack Valheim `5.4.2350`
- Jotunn `2.30.1`
- PlantEverything `1.21.2`
- Seasonality `3.8.3`
- YamlDotNet `16.3.1`
- RecyclePlus `1.3.3`
- Sailing `1.1.8`

### Client-side QoL

These are included in the recommended client profile but do not need to be installed on the dedicated server:

- PlantEasily `2.2.0`
- RunicBuildCamera `1.0.4`
- CraftFromContainers `4.0.30`
- BetterUI ForeverMaintained `2.5.12`

Using the included Thunderstore profile is recommended so all players use the tested configuration.

---

# Thunderstore Client Profile

A ready-to-import Thunderstore profile is included in this repository:

```text
client-profile/TutSpokiino_VanillaPlus.r2z
```

The profile contains the complete tested client modpack with matching versions for the dedicated server.

## Included Client Mods

| Mod | Version | Type |
| --- | --- | --- |
| BepInExPack Valheim | 5.4.2350 | Core |
| Jotunn | 2.30.1 | Server-synced dependency |
| PlantEverything | 1.21.2 | Server-synced |
| Seasonality | 3.8.3 | Server-synced |
| YamlDotNet | 16.3.1 | Dependency |
| RecyclePlus | 1.3.3 | Server-synced |
| Sailing | 1.1.8 | Server-synced |
| PlantEasily | 2.2.0 | Client QoL |
| RunicBuildCamera | 1.0.4 | Client QoL |
| CraftFromContainers | 4.0.30 | Client QoL |
| BetterUI ForeverMaintained | 2.5.12 | Client QoL |

The exported profile has been cleaned of obsolete InventorySlots and QuickStack configuration files.

## Importing the Thunderstore Profile

1. Install and open Thunderstore Mod Manager.
2. Select **Valheim**.
3. Open the profile import option.
4. Choose to import a profile from a file.
5. Select:

```text
client-profile/TutSpokiino_VanillaPlus.r2z
```

6. Allow Thunderstore to install the profile and dependencies.
7. Launch Valheim using **Modded** mode.

Do not manually enable `Groups`, `InventorySlots`, `TargetPortal`, or other untested server-synced mods.

Additional client-only mods should also be tested before adding them to the shared profile.

---

# Requirements

You need:

- Docker Desktop or Docker Engine
- Docker Compose
- `curl`
- `unzip`

## Architecture

The included Docker configuration currently uses:

```text
tsxcloud/valheim-arm:arm64-fex
```

with:

```yaml
platform: linux/arm64
```

This configuration is intended for **ARM64**, including Apple Silicon Macs.

If your server runs on AMD64 / x86_64 hardware, the Docker image/platform configuration must be adapted before starting.

---

# Installation

## 1. Clone the Repository

```bash
git clone https://github.com/bsimokop-rgb/valheim-vanillaplus-server.git
cd valheim-vanillaplus-server
```

---

## 2. Create the Local Environment File

Copy the example configuration:

```bash
cp .env.example .env
```

Open `.env` and configure your own server:

```env
SERVER_NAME=Valheim Vanilla+
SERVER_WORLD=MyValheimWorld
SERVER_PASSWORD=change_me

SERVER_VISIBILITY=0
ENABLE_CROSSPLAY=false
ENABLE_PLUGINS=true

SERVER_SAVE_INTERVAL=900
SERVER_BACKUPS=8
SERVER_BACKUP_SHORT=3600
SERVER_BACKUP_LONG=43200
```

Change at minimum:

```text
SERVER_NAME
SERVER_WORLD
SERVER_PASSWORD
```

`.env` is excluded from Git and should never be committed.

---

# First Server Setup

## 3. Initialize the Valheim Server

Run:

```bash
docker compose up
```

The first launch will download and initialize the Valheim dedicated server.

Wait until the logs eventually show:

```text
Opened Steam server
```

Then stop the server cleanly with:

```text
Ctrl+C
```

Wait until the container reports that it has stopped.

---

## 4. Install the Server Modpack

Run:

```bash
./install-mods.sh
```

The script will automatically:

1. remove the incompatible bundled `ServerDevcommands.dll` if present
2. update BepInExPack to `5.4.2350`
3. install Jotunn `2.30.1`
4. install PlantEverything `1.21.2`
5. install Seasonality `3.8.3`
6. install YamlDotNet `16.3.1`
7. install RecyclePlus `1.3.3`
8. install Sailing `1.1.8`

The script does not install or replace a world save.

After installation, the expected output ends with:

```text
Server modpack installed successfully.
```

---

# Starting the Server

Foreground mode:

```bash
docker compose up
```

Detached/background mode:

```bash
docker compose up -d
```

Follow logs:

```bash
docker compose logs -f valheim
```

Check container status:

```bash
docker compose ps
```

Stop a detached server cleanly:

```bash
docker compose down
```

For normal maintenance, always allow Valheim to shut down cleanly so the world is saved correctly.

---

# Networking

The server exposes these UDP ports:

```text
2456
2457
2458
```

For LAN connections:

```text
LOCAL_SERVER_IP:2456
```

For players outside the local network, configure UDP port forwarding on the router:

```text
2456 -> SERVER_LOCAL_IP:2456
2457 -> SERVER_LOCAL_IP:2457
2458 -> SERVER_LOCAL_IP:2458
```

External players can then connect using:

```text
PUBLIC_IP:2456
```

If the server's local IP changes, router port forwarding may need to be updated.

If the ISP changes the public IP, external players will need the new address.

No private IP addresses or passwords are stored in this repository.

---

# Saves

Server runtime and world data are created locally in:

```text
valheim/server/
valheim/saves/
```

Both directories are excluded from Git.

This means cloning this repository does **not** copy another server's world or player progression.

The world name is controlled by:

```env
SERVER_WORLD=MyValheimWorld
```

If that world does not exist, Valheim will create it automatically.

---

# Save & Backup Configuration

Default configuration in this repository:

```text
Autosave interval: 15 minutes
Backup count: 8
Short backup interval: 1 hour
Long backup interval: 12 hours
```

Corresponding environment variables:

```env
SERVER_SAVE_INTERVAL=900
SERVER_BACKUPS=8
SERVER_BACKUP_SHORT=3600
SERVER_BACKUP_LONG=43200
```

Before major mod changes or Valheim updates, make an additional manual backup.

Do not use an active world as the first test target for major modpack changes.

---

# Checking Installed Server Mods

After installation:

```bash
find ./valheim/server/BepInEx/plugins -maxdepth 1 -type f -print
```

Expected gameplay/server plugins include:

```text
Jotunn.dll
Advize_PlantEverything.dll
Seasonality.dll
YamlDotNet.dll
RecyclePlus.dll
Sailing.dll
```

The Docker image may also include its own utility plugins.

`ServerDevcommands.dll` should **not** be present after running `install-mods.sh`.

To verify:

```bash
find ./valheim/server/BepInEx/plugins \
  -maxdepth 1 \
  -type f \
  -iname '*ServerDevcommands*' \
  -print
```

Expected result:

```text
(no output)
```

---

# Healthy Startup

A healthy server should eventually reach:

```text
Registering lobby
Opened Steam server
```

Some warnings are normal on a headless dedicated server, especially messages related to:

```text
DepthOfField
Shader
GBuffer
Null graphics device
Camera effects
```

These are generally unrelated to gameplay or networking.

For a quick critical-error check:

```bash
docker compose logs --since=5m valheim | \
grep -Ei 'ServerDevcommands|HarmonyException|MissingMethodException|Could not load|ArgumentException'
```

On a healthy tested configuration, this should normally produce no output.

---

# Troubleshooting

## Server Does Not Start

Check:

```bash
docker compose ps
```

Then inspect recent logs:

```bash
docker compose logs --tail=200 valheim
```

---

## Player Cannot Connect

Check:

1. the server is running
2. client Valheim version matches the server
3. required mod versions match
4. UDP ports `2456-2458` are forwarded
5. firewall allows Docker / Valheim traffic
6. the correct public or LAN IP is being used
7. the player launched Valheim in **Modded** mode when using the shared profile

---

## Mod Version Mismatch

The simplest fix is to import the included Thunderstore profile again:

```text
client-profile/TutSpokiino_VanillaPlus.r2z
```

Avoid individually updating mods on only one client.

A newer mod version is not automatically better for an existing server.

---

## Infinite Loading After Password

First test whether the issue exists without mods.

Back up the world before changing anything.

Typical isolation order:

1. test with server plugins disabled
2. test with a vanilla client
3. test a temporary fresh world
4. inspect server logs
5. inspect client `BepInEx/LogOutput.log`

If a new world works but an existing world does not, suspect the world save rather than networking.

Do not immediately overwrite the problematic world.

Preserve it and test a backup or recovery copy first.

---

## Problems After Death or Respawn

A server that starts successfully can still have mod or world-save problems.

Test:

1. joining the server
2. moving around the world
3. interacting with containers and building pieces
4. sleeping if relevant
5. dying
6. respawning
7. reconnecting
8. joining with a second player

If death or respawn causes infinite loading, compare behavior on a temporary fresh world before assuming the networking configuration is broken.

---

# Updating Valheim or Mods

Do not blindly update a working server.

Recommended process:

1. stop the server cleanly
2. back up the world
3. check Valheim/mod compatibility
4. update the smallest possible group of mods
5. start the server
6. inspect logs
7. test connection
8. test gameplay
9. test death and respawn
10. test with a second player
11. only then continue normal gameplay

A mod that loads without crashing can still be incompatible with networking, world loading, synchronization, or respawning.

If the client modpack changes, export a new Thunderstore `.r2z` profile and replace the old profile in:

```text
client-profile/
```

---

# Repository Structure

```text
valheim-vanillaplus-server/
├── .env.example
├── .gitignore
├── README.md
├── compose.yml
├── install-mods.sh
└── client-profile/
    └── TutSpokiino_VanillaPlus.r2z
```

Generated locally after first launch:

```text
valheim/
├── server/
└── saves/
```

Those runtime directories are intentionally excluded from the repository.

The local `.env` file is also excluded and must never be committed.

---

# Tested Setup Flow

The repository has been tested from a clean clone using the following flow:

```text
Clean clone
    ↓
Create .env
    ↓
Validate Docker Compose
    ↓
First vanilla server initialization
    ↓
Generate fresh world
    ↓
Stop server
    ↓
Run install-mods.sh
    ↓
Start modded server
    ↓
Verify BepInEx / Jotunn / server mods
    ↓
Verify no critical compatibility exceptions
    ↓
Opened Steam server
```

This verifies that the repository can bootstrap a fresh server without relying on files from the original development environment.

---

# Vanilla+ Philosophy

This setup is intended as a Vanilla+ experience.

The priorities are:

- preserve core Valheim progression
- improve quality of life
- avoid replacing the core gameplay loop
- keep the server reproducible
- keep client configurations synchronized
- prioritize stability over mod quantity
- test changes before applying them to an active world

When in doubt, back up the world before changing the modpack.