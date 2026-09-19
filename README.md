# Valheim Vanilla+ Dedicated Server

A reproducible Docker-based Valheim dedicated server with a lightweight Vanilla+ modpack.

This repository contains:

- Docker server configuration
- automatic server-side mod installation
- recommended client mod list
- backup/save configuration

It does **not** contain:

- world saves
- passwords
- player progress
- private server data

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

These mods were tested but removed because of compatibility/stability problems with the current Valheim version:

| Mod | Version | Reason |
| --- | --- | --- |
| Groups | 1.2.10 | `MissingMethodException` / Chat & ConsoleCommand incompatibility |
| InventorySlots | 1.5.4 | instability during testing |
| TargetPortal | 1.2.3 | Harmony / API compatibility errors |

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

These can be installed on players' clients and do not need to be installed on the dedicated server:

- PlantEasily `2.2.0`
- RunicBuildCamera `1.0.4`
- CraftFromContainers `4.0.30`
- BetterUI ForeverMaintained `2.5.12`

Using a shared Thunderstore profile is recommended so everyone has matching versions.

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
````

with:

```yaml
platform: linux/arm64
```

This configuration is intended for **ARM64**, including Apple Silicon Macs.

If your server runs on AMD64 / x86_64 hardware, the Docker image/platform configuration must be adapted before starting.

---

# Installation

## 1. Clone the repository

```bash
git clone <REPOSITORY_URL>
cd valheim-vanillaplus-server
```

---

## 2. Create the local environment file

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

## 3. Initialize the Valheim server

Run:

```bash
docker compose up
```

The first launch will download and initialize the Valheim dedicated server.

Wait until the logs eventually show:

```text
Opened Steam server
```

Then stop the server cleanly:

```text
Ctrl+C
```

Wait until the container reports that it has stopped.

---

## 4. Install the server modpack

Run:

```bash
./install-mods.sh
```

The script will automatically:

1. update BepInExPack to `5.4.2350`
2. install Jotunn
3. install PlantEverything
4. install Seasonality
5. install YamlDotNet
6. install RecyclePlus
7. install Sailing

The script does not install a world save.

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

Stop a detached server:

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

---

# Troubleshooting

## Server does not start

Check:

```bash
docker compose ps
```

Then inspect recent logs:

```bash
docker compose logs --tail=200 valheim
```

---

## Player cannot connect

Check:

1. server is running
2. client Valheim version matches the server
3. required mod versions match
4. UDP ports `2456-2458` are forwarded
5. firewall allows Docker / Valheim traffic
6. the correct public or LAN IP is being used

---

## Infinite loading after password

First test whether the issue exists without mods.

Back up the world before changing anything.

Typical isolation order:

1. test with server plugins disabled
2. test with a vanilla client
3. test a temporary fresh world
4. inspect server logs
5. inspect client `BepInEx/LogOutput.log`

If a new world works but an existing world does not, suspect the world save rather than networking.

Do not immediately overwrite the problematic world. Preserve it and test a backup/recovery copy first.

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
8. test death and respawn
9. test with a second player
10. only then continue normal gameplay

A mod that loads without crashing can still be incompatible with networking, world loading or respawning.

---

# Repository Structure

```text
valheim-vanillaplus-server/
├── .env.example
├── .gitignore
├── README.md
├── compose.yml
└── install-mods.sh
```

Generated locally after first launch:

```text
valheim/
├── server/
└── saves/
```

Those runtime directories are intentionally excluded from the repository.

---

# Notes

This setup is intended as a Vanilla+ experience:

* core Valheim progression remains intact
* no world save is distributed
* QoL improvements are preferred over major gameplay replacement
* server stability takes priority over adding more mods

When in doubt, back up the world before changing the modpack.

````