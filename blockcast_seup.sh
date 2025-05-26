#!/bin/bash

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
RESET='\033[0m'
BOLD='\033[1m'

# ===============================
# BANNER
# ===============================
echo -e "${PURPLE}${BOLD}"
echo -e "${CYAN}
 ______              _         _                                             
|  ___ \            | |       | |                   _                        
| |   | |  ___    _ | |  ____ | | _   _   _  ____  | |_   ____   ____  _____ 
| |   | | / _ \  / || | / _  )| || \ | | | ||  _ \ |  _) / _  ) / ___)(___  )
| |   | || |_| |( (_| |( (/ / | | | || |_| || | | || |__( (/ / | |     / __/ 
|_|   |_| \___/  \____| \____)|_| |_| \____||_| |_| \___)\____)|_|    (_____)                   
                                
${BLUE}                      :: Powered by Noderhunterz ::
${RESET}"
echo -e "${CYAN}${BOLD}--- Docker Environment Setup for Blockcast ---${RESET}"

# ===============================
# Step 1: Docker Installation
# ===============================
if ! command -v docker &> /dev/null; then
  echo -e "${CYAN}${BOLD}--- Installing Docker (Official Method) ---${RESET}"

  if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
    echo -e "${RED}[WARNING] Removing unsupported NodeSource repository...${RESET}"
    sudo rm /etc/apt/sources.list.d/nodesource.list
  fi

  echo -e "${CYAN}Removing old Docker versions (if any)...${RESET}"
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y $pkg &>/dev/null || true
  done

  echo -e "${CYAN}Setting up Docker repository...${RESET}"
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" |
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  echo -e "${CYAN}Installing Docker components...${RESET}"
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo -e "${CYAN}Adding user '${USER}' to the docker group...${RESET}"
  sudo usermod -aG docker "$USER"
  newgrp docker
  sudo systemctl enable docker
  sudo systemctl restart docker

  echo -e "${GREEN}${BOLD}Testing Docker with hello-world...${RESET}"
  docker run hello-world || {
    echo -e "${RED}${BOLD}Docker test failed. Please restart your shell or log out and back in.${RESET}"
    exit 1
  }
else
  echo -e "${GREEN}${BOLD}Docker is already installed. Skipping installation.${RESET}"
fi

echo -e "${CYAN}${BOLD}--- Configuring UFW Firewall Rules ---${RESET}"

# Check if ufw is installed, install if not
if ! command -v ufw &>/dev/null; then
  echo -e "${CYAN}Installing ufw...${RESET}"
  sudo apt-get update -y
  sudo apt-get install -y ufw
fi

# Allow necessary ports
echo -e "${CYAN}Allowing ports 22 (SSH), 8443 (Blockcast UI)...${RESET}"
sudo ufw allow 22
sudo ufw allow 8443

# Enable UFW if not already active
UFW_STATUS=$(sudo ufw status | grep -i "Status: active")
if [ -z "$UFW_STATUS" ]; then
  echo -e "${CYAN}Enabling UFW firewall...${RESET}"
  sudo ufw --force enable
else
  echo -e "${GREEN}UFW is already enabled.${RESET}"
fi

# Reload rules
echo -e "${CYAN}Reloading UFW firewall rules...${RESET}"
sudo ufw reload

# ===============================
# Step 2: Setup Project Directory
# ===============================
WORKDIR="$HOME/blockcast-node"
echo -e "${CYAN}Creating working directory at ${WORKDIR}${RESET}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ===============================
# Step 3: Ask for Watchtower Port
# ===============================
DEFAULT_PORT="8080"
CUSTOM_PORT="$DEFAULT_PORT"

read -p "$(echo -e "${CYAN}Do you want to change the default Watchtower port (${DEFAULT_PORT})? (y/n): ${RESET}")" change_port
if [ "$change_port" = "y" ] || [ "$change_port" = "Y" ]; then
  read -p "$(echo -e "${CYAN}Enter the new port to expose Watchtower on (e.g., 8081): ${RESET}")" input_port
  if echo "$input_port" | grep -qE '^[0-9]+$'; then
    CUSTOM_PORT="$input_port"
    echo -e "${GREEN}Using custom Watchtower port: $CUSTOM_PORT${RESET}"
  else
    echo -e "${RED}Invalid port entered. Falling back to default: $DEFAULT_PORT${RESET}"
  fi
else
  echo -e "${GREEN}Using default Watchtower port: $DEFAULT_PORT${RESET}"
fi


# ===============================
# Step 4: Generate docker-compose.yml
# ===============================
DOCKER_COMPOSE_FILE="$WORKDIR/docker-compose.yml"
echo -e "${CYAN}Creating docker-compose.yml...${RESET}"

cat <<EOF > $DOCKER_COMPOSE_FILE
x-service: &service
  image: blockcast/cdn_gateway_go:\${IMAGE_VERSION:-stable}
  restart: unless-stopped
  network_mode: "service:blockcastd"
  volumes:
    - \${HOME}/.blockcast/certs:/var/opt/magma/certs
    - \${HOME}/.blockcast/snowflake:/etc/snowflake
  labels:
    - "com.centurylinklabs.watchtower.enable=true"

services:
  control_proxy:
    <<: *service
    container_name: control_proxy
    command: /usr/bin/control_proxy

  blockcastd:
    <<: *service
    container_name: blockcastd
    command: /usr/bin/blockcastd -logtostderr=true -v=0
    network_mode: bridge

  beacond:
    <<: *service
    container_name: beacond
    command: /usr/bin/beacond -logtostderr=true -v=0

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_LABEL_ENABLE=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "${CUSTOM_PORT}:8080"
EOF

# ===============================
# Step 5: Start Docker Services
# ===============================
echo -e "${CYAN}Starting services with Docker Compose...${RESET}"
docker compose up -d

# ===============================
# Step 6: Initialize Node
# ===============================
echo -e "${CYAN}Waiting 5 seconds for containers to stabilize...${RESET}"
sleep 5
echo -e "${CYAN}Initializing blockcast node...${RESET}"
docker compose exec blockcastd blockcastd init || {
  echo -e "${RED}Failed to initialize blockcastd. Check logs with: docker compose logs -f blockcastd${RESET}"
  exit 1
}
echo -e "${CYAN}${BOLD}--- Detecting Public IP and Location ---${RESET}"

IP=$(curl -s ipv4.icanhazip.com)
if [ -z "$IP" ]; then
  echo -e "${RED}Failed to detect public IP address.${RESET}"
else
  echo -e "${GREEN}Your public IP is: ${BOLD}$IP${RESET}"
  
  # Fetch geolocation info
  LOCATION=$(curl -s "https://ipinfo.io/${IP}/json" | jq -r '.city, .region, .country' 2>/dev/null | paste -sd ', ')
  
  if [ -n "$LOCATION" ]; then
    echo -e "${CYAN}Detected Location: ${BOLD}$LOCATION${RESET}"
  else
    echo -e "${RED}Could not determine location from IP.${RESET}"
  fi
fi

echo -e "${GREEN}${BOLD}🎉 Node initialized successfully!${RESET}"
echo -e "${CYAN}Use the registration URL or copy the Hardware ID and Challenge Key to register manually.${RESET}"
