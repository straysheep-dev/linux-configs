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


echo -e "[${BLUE}>${RESET}] ${BOLD}Updating all system packages...${RESET}"

# Package managers
if (grep -Pqx '^ID=kali$' /etc/os-release); then
	sudo apt update
	sudo apt full-upgrade -y
	sudo apt autoremove --purge -y
	sudo apt-get clean
elif (command -v apt > /dev/null); then
	sudo apt update
	sudo apt upgrade -y
	sudo apt autoremove --purge -y
	sudo apt-get clean
elif (command -v dnf > /dev/null); then
	sudo dnf upgrade -y
	sudo dnf autoremove -y
	sudo dnf clean all
fi

# Additional package Managers
if (command -v snap > /dev/null); then
	true
	sudo snap refresh
fi

if (command -v flatpak > /dev/null); then
	true
	sudo flatpak update
fi

# IDS
if (command -v rkhunter > /dev/null); then
	echo ""
	echo -e "[${BLUE}>${RESET}] ${BOLD}Updating rkhunter database...${RESET}"
	sudo rkhunter --propupd
	sudo sha256sum /var/lib/rkhunter/db/*\.*
fi

if (command -v aide > /dev/null); then
	echo ""
	echo -e "[${BLUE}>${RESET}] ${BOLD}Updating aide database...${RESET}"
	sudo aide --config-check -c /etc/aide/aide.conf
	sudo aide -u -c /etc/aide/aide.conf | grep -A 50 -F 'The attributes of the (uncompressed) database(s):'
	sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
fi

echo ""
echo -e "[${YELLOW}i${RESET}] ${BOLD}Save the above values to your password manager${RESET}"
echo "=================================================="
echo ""

if (sudo dmesg | grep -iPq 'hypervisor'); then

	echo -e "[${YELLOW}i${RESET}] ${BOLD}Virtual Machine detected.${RESET}"
	echo ""

	echo -e "[${BLUE}>${RESET}] ${BOLD}Vacuuming journal files...${RESET}"
	sudo journalctl --rotate --vacuum-size 10M

	echo ""
	echo -e "[${BLUE}>${RESET}] ${BOLD}Getting available disk space...${RESET}"
	# Attempt to find the device name where the root filesystem exists
	DEV_NAME="$(mount | grep -P 'on / ' | cut -d ' ' -f 1)"
	# https://www.gnu.org/software/gawk/manual/gawk.html#Print-Examples
	DISK_STATS="$(df -hl | grep "$DEV_NAME" | awk '{print $2"\t"$3"\t"$4"\t"$5"\t"$6}')"
	echo -e "${YELLOW}${BOLD}Size\tUsed\tAvail\tUse%\tMounted on${RESET}"
	echo -e "${BOLD}$DISK_STATS${RESET}"
	echo -e ""
	echo -e "${BOLD}Prepare to compact virtual disk with 'dd'?${RESET}"
	echo -e "${BOLD}(overwrites free space with /dev/zero, to clone or compress)${RESET}"
	echo -e ""
	until [[ $DD_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "[y/n]: " -e -i n DD_CHOICE
		done

	if [ "$DD_CHOICE" == "y" ]; then
		echo ""
		dd if=/dev/zero of=~/zerofill bs=4M status=progress
		rm ~/zerofill
	fi
fi

echo -e "[${BLUE}✓${RESET}] ${BOLD}Done.${RESET}"
exit 0
