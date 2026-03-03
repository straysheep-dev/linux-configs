#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 straysheep-dev

# shellcheck disable=SC2034

# Designed for local use on systems without some type of remote monitoring and integrity tool installed.
# Currently supports:
#   - aide
#   - rkhunter
#
# Run this after reviewing the integrity of the system. All local IDS databases are updated. Ensure the updated
# databases are moved to some type of write-protected storage.
#
# Running in a VM has the option to write freespace with /dev/zero to prepare the VM disk image for compression

BLUE="\033[01;34m"
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
RED="\033[01;31m"
BOLD="\033[01;01m"
RESET="\033[00m"


# IDS
if (command -v rkhunter > /dev/null); then
	echo ""
	echo -e "[${BLUE}>${RESET}] ${BOLD}Updating rkhunter database...${RESET}"
	sudo rkhunter --propupd
	sudo sha256sum /var/lib/rkhunter/db/*\.*
fi

if (command -v aide > /dev/null); then
	if [ -f /etc/aide.conf ]; then
		# fedora
		AIDE_CONF='/etc/aide.conf'
	elif [ -f /etc/aide/aide.conf ]; then
		# debian / ubuntu
		AIDE_CONF='/etc/aide/aide.conf'
	fi
	echo ""
	echo -e "[${BLUE}>${RESET}] ${BOLD}Updating aide database...${RESET}"
	sudo aide --config-check -c "$AIDE_CONF"
	sudo aide -u -c "$AIDE_CONF" | grep -A 50 -F 'The attributes of the (uncompressed) database(s):'
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
