#!/bin/bash

# Installs docker on Ubuntu

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

function InstallDocker() {

	# For changes, check the following link:
	# https://docs.docker.com/engine/install/
	# https://docs.docker.com/engine/install/ubuntu/

	echo -e "${BLUE}[>]Installing Docker's official apt repo...${RESET}"

	if ! [ -e /etc/apt/keyrings/docker.gpg ]; then

	# Update apt, install necessary packages:
	sudo apt-get update
	sudo apt-get install ca-certificates curl gnupg

	# Add Docker’s official GPG key:
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg

	# Add the repository information:
	echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	# If the key changes, review the following link for references to the new key:
	# https://keyserver.ubuntu.com/pks/lookup?search=9DC858229FC7DD38854AE2D88D81803C0EBFCD88&fingerprint=on&op=index
	if ! (gpg /etc/apt/keyrings/docker.gpg | grep -P "9DC8\s?5822\s?9FC7\s?DD38\s?854A\s?\s?E2D8\s?8D81\s?803C\s?0EBF\s?CD88"); then echo -e "${RED}BAD SIGNATURE${RESET}"; exit; else echo -e "[${GREEN}OK${RESET}]"; fi

	fi

	if ! (command -v docker > /dev/null); then
		apt-get update
		apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	fi

	if ! (systemctl is-active docker); then
		sleep 5
		systemctl restart docker
	fi

	if (command -v docker > /dev/null); then
		echo -e "${BLUE}[*]Getting docker version information...${RESET}"
		sleep 1
		docker version
		echo -e "${BLUE}[✓]docker installed.${RESET}"
	else
		echo "No version detected, quitting..."
		exit 1
	fi

}

InstallDocker
