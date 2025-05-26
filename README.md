
# Blockcast CDN Gateway - One-Click Setup Script

This repository provides a **one-click automated setup script** to install Docker (if missing) and deploy the [Blockcast](https://blockcast.network) CDN Gateway using Docker Compose.

## Register here first and connect your phantom wallet before moving forward

[Blockcast](https://app.blockcast.network)

---

## Features

- Installs Docker using the official method (Ubuntu-compatible)
- Adds user to the Docker group
- Creates necessary folders for certificates and configs
- Prompts to change Watchtower's port from `8080` to `8081`
- Sets up Blockcast services: `blockcastd`, `control_proxy`, `beacond`, `watchtower`
- Runs all containers using Docker Compose
- Automatically restarts containers on failure

---


## Update dependencies 
```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install ufw git
```
---

## Allow Firewall
```bash
sudo ufw allow 22
sudo ufw allow ssh
sudo ufw allow 8443
sudo ufw enable
```
---
## Setup Command

Run this command in your terminal:

```bash
git clone https://github.com/CodeDialect/Blockcast.git
cd Blockcast/
chmod +x blockcast_seup.sh
./blockcast_seup.sh
```

---

## Check your city and country

```bash
curl ipinfo.io
```

## What the Script Does

1. Installs Docker CE if not found
2. Cleans up conflicting or legacy Docker installations
3. Adds user to the `docker` group for permission-free use
4. Creates required directories at:
   - `${HOME}/.blockcast/certs`
   - `${HOME}/.blockcast/snowflake`
5. Writes a `docker-compose.yml` with the Blockcast services
6. Optionally changes Watchtower port to avoid conflicts
7. Brings up the full stack with `docker compose up -d`
8. Displays helpful log commands for monitoring

---

## Docker Services

- **blockcastd**: Main node container
- **control_proxy**: Manages control-plane commands
- **beacond**: Supports beaconing functionality
- **watchtower**: Auto-updates Docker containers with labels

---

## After Installation

### Initialize Your Node

```bash
docker compose exec blockcastd blockcastd init
```

- You"ll get a registration URL.
- Alternatively, use the Hardware ID + Challenge Key to register manually.

---

## View Logs

```bash
docker logs blockcastd -f
```
---

## Restart your Blockcast
```bash
docker restart blockcastd
```
---

## Requirements

- Ubuntu (or Debian-based Linux)
- `sudo` privileges
- Internet access

---

## Troubleshooting

- Docker permission error? Run `newgrp docker` or restart your session.
- Missing Docker socket? Ensure Docker is running: `sudo systemctl status docker`

---

## Community

Visit the official site: [https://www.blockcast.network](https://www.blockcast.network)

---

## Powered by

```
 ______              _         _                                             
|  ___ \            | |       | |                   _                        
| |   | |  ___    _ | |  ____ | | _   _   _  ____  | |_   ____   ____  _____ 
| |   | | / _ \  / || | / _  )| || \ | | | ||  _ \ |  _) / _  ) / ___)(___  )
| |   | || |_| |( (_| |( (/ / | | | || |_| || | | || |__( (/ / | |     / __/ 
|_|   |_| \___/  \____| \____)|_| |_| \____||_| |_| \___)\____)|_|    (_____)                   

:: Powered by Noderhunterz
```
