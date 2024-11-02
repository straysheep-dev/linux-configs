#!/bin/bash

# Run this weekly or daily as part of normal system maintenance

BLUE="\033[01;34m"
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
RED="\033[01;31m"
BOLD="\033[01;01m"
RESET="\033[00m"

function PrintUpdatingSystemPackages() {
	echo -e "[${BLUE}>${RESET}] ${BOLD}Updating all system packages...${RESET}"
}
function PrintUpdatingSnapPackages() {
	echo -e "[${BLUE}>${RESET}] ${BOLD}Updating all snap packages...${RESET}"
}
function PrintUpdatingFlatpakApps() {
	echo -e "[${BLUE}>${RESET}] ${BOLD}Updating all flatpak applications...${RESET}"
}
function PrintUpdatingFirmware() {
	echo -e "[${BLUE}>${RESET}] ${BOLD}Checking for available firmware updates...${RESET}"
}

if (grep -Pqx '^ID=kali$' /etc/os-release); then
	PrintUpdatingSystemPackages
	sudo apt update -q
	sudo PATH="$PATH":/usr/bin \
	DEBIAN_FRONTEND=noninteractive \
	apt full-upgrade -yq
	sudo apt autoremove --purge -yq
	sudo apt-get clean
elif (command -v apt > /dev/null); then
	PrintUpdatingSystemPackages
	sudo apt update -q
	sudo PATH="$PATH":/usr/bin \
	DEBIAN_FRONTEND=noninteractive \
	NEEDRESTART_MODE=a \
	apt upgrade -yq
	sudo apt autoremove --purge -yq
	sudo apt-get clean
elif (command -v dnf > /dev/null); then
	PrintUpdatingSystemPackages
	sudo dnf upgrade -yq
	sudo dnf autoremove -yq
	sudo dnf clean all
fi

if (command -v snap > /dev/null); then
	true
	PrintUpdatingSnapPackages
	sudo snap refresh
fi

if (command -v flatpak > /dev/null); then
	true
	PrintUpdatingFlatpakApps
	sudo flatpak update  # Need to check for a -yq option
fi

if (sudo dmesg | grep -iPq 'hypervisor'); then
	true
else
	# [BHIS | Firmware Enumeration with Paul Asadoorian](https://www.youtube.com/watch?v=G0hF76nBE7E)
	if (command -v fwupdmgr > /dev/null); then
		if (fwupdmgr --version | grep -F 'runtime   org.freedesktop.fwupd' | awk '{print $3}' | grep -P "[1-2]\.[8-9]\.[0-9]" > /dev/null); then
			PrintUpdatingFirmware
			fwupdmgr get-updates && \
			fwupdmgr update
		fi
	fi
fi
