#!/bin/bash

# Run this after reviewing the integrity of the system
# Updates all system packages, then IDS databases
# Running in a VM has the option to write freespace with /dev/zero to prepare the VM disk image for compression

BLUE="\033[01;34m"
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
RED="\033[01;31m"
BOLD="\033[01;01m"
RESET="\033[00m"


echo -e "[${BLUE}>${RESET}]Updating all system packages..."

# Package managers
if (grep -Pqx '^ID=kali$' /etc/os-release); then
	sudo apt update && \
	sudo apt full-upgrade -y && \
	sudo apt autoremove --purge -y && \
	sudo apt-get clean
elif (command -v apt > /dev/null); then
	sudo apt update && \
	sudo apt upgrade -y && \
	sudo apt autoremove --purge -y && \
	sudo apt-get clean
elif (command -v dnf > /dev/null); then
	sudo dnf upgrade -y && \
	sudo dnf autoremove -y && \
	sudo dnf clean all
fi

# Additional package Managers
if (command -v snap > /dev/null); then
	true
	sudo snap refresh
fi

if (command -v flatpak > /dev/null); then
	true
	#sudo flatpak update
fi

# IDS
if (command -v rkhunter > /dev/null); then
	echo -e "[${BLUE}>${RESET}]Updating rkhunter database..."
	sudo rkhunter --propupd
fi

if [ -e '/var/lib/aide/aide.db' ]; then
	echo -e "[${BLUE}>${RESET}]Updating aide database..."
	sudo aide -u -c /etc/aide/aide.conf
	sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
fi

if (command -v rkhunter > /dev/null); then
	echo ""
	sudo sha256sum /var/lib/rkhunter/db/*\.*
fi

echo ""
echo -e "[${YELLOW}i${RESET}] ${BOLD}Save the above values to your password manager${RESET}"
echo "=================================================="
echo ""

if (dmesg | grep -iPq 'hypervisor'); then

	sudo journalctl --rotate --vacuum-size 10M

	echo ""
	echo "Prepare to compact virtual disk with 'dd'?"
	echo "(overwrites free space with /dev/zero, to clone or compress)"
	echo ""
	until [[ $DD_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "[y/n]: " -e -i n DD_CHOICE
		done

	if [ "$DD_CHOICE" == "y" ]; then
		echo ""
		dd if=/dev/zero of=~/zerofill bs=4M status=progress
		rm ~/zerofill
	fi
fi

echo -e "[${BLUE}✓${RESET}]Done."
exit 0
