#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 straysheep-dev

# shellcheck disable=SC2034

# Run this weekly or daily as part of normal system maintenance
#
# Cron Example (run as root) for daily updates at 3a local time, reboot at 4a if needed:
# m h  dom mon dow   command
# 0 3 * * * /bin/bash /usr/local/bin/update-packages.sh
# 0 4 * * * /bin/bash -c 'if [[ -e /run/reboot-required ]]; then sudo systemctl reboot; fi'
#
# For systemd-timer examples: https://github.com/straysheep-dev/ansible-role-configure_updates

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
function PrintSkippingFirmware() {
	echo -e "[${YELLOW}*${RESET}] ${BOLD}Skipping firmware updates, detected incompatible system or non-interactive session...${RESET}"
}
function PrintUpdatingSystemPackagesError() {
	echo -e "[${RED}*${RESET}] ${BOLD}Package manager not detected. Exiting.${RESET}"
}

# APT Related Settings
#
# DEBIAN_FRONTEND=noninteractive sets apt to run without live input from a user or admin
# NEEDRESTART_MODE=a is an Ubuntu-specific setting (from 22.04 LTS and later) that automatically restarts services when necessary
# Options are "a" to auto-restart services unattended, "l" to only list services needing a restart, or "i" to prompt interactively
# https://github.com/liske/needrestart/issues/109
# https://github.com/liske/needrestart/blob/master/man/needrestart.1
#
# Even with the previous variables set, you may be prompted to manage configuration file
# changes via dpkg, for example when you've modified a file and an update ships a new one.
# -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' will automate this.
# - https://wiki.debian.org/AutomatedUpgrade
# - https://manpages.debian.org/bullseye/debconf-doc/debconf.7.en.html#Frontends
# - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html#parameter-dpkg_options

if (grep -Pqx '^ID=kali$' /etc/os-release); then
	PrintUpdatingSystemPackages
	sudo apt update -q
	sudo PATH="$PATH":/usr/bin \
	DEBIAN_FRONTEND=noninteractive \
	apt full-upgrade -y \
	-o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
	sudo apt autoremove --purge -yq
	sudo apt-get clean
elif (command -v apt > /dev/null); then
	PrintUpdatingSystemPackages
	sudo apt update -q
	sudo PATH="$PATH":/usr/bin \
	DEBIAN_FRONTEND=noninteractive \
	NEEDRESTART_MODE=a \
	apt full-upgrade -y \
	-o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
	sudo apt autoremove --purge -yq
	sudo apt-get clean
elif (command -v dnf > /dev/null); then
	PrintUpdatingSystemPackages
	sudo dnf upgrade -yq
	sudo dnf autoremove -yq
	sudo dnf clean all
else
	PrintUpdatingSystemPackagesError
	exit 1
fi

if (command -v snap > /dev/null); then
	true
	PrintUpdatingSnapPackages
	sudo snap refresh
fi

if (command -v flatpak > /dev/null); then
	true
	PrintUpdatingFlatpakApps
	# Automating updates through flatpak has some risk. See the post the Arch Linux Wiki points to.
	# https://wiki.archlinux.org/title/Flatpak#Automatic_updates_via_systemd
	# Applications can gain new permissions that you may not have a preconfigured setting for.
	# This needs reviewed.
	sudo flatpak update --noninteractive --assumeyes
fi

if [ -e /proc/device-tree/compatible ]; then
	# Check Raspberry Pi model and CPU across distributions (better than /proc/cpuinfo)
	# https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#best-practices-for-revision-code-usage
	if tr '\0' '\n' < /proc/device-tree/compatible | grep -iq 'raspberrypi'; then
		PrintSkippingFirmware
		# TODO: Check Raspberry Pi firmware update methods
	fi
elif (command -v systemd-detect-virt > /dev/null); then
	# Detect execution in a virtualized environment, this also works on containers
	if systemd-detect-virt --quiet; then
		PrintSkippingFirmware
	fi
elif [ ! -t 0 ]; then
	# `-t fd`, True if file descriptor "fd" is open and refers to a terminal.
	# It also appears to work in other shells like /bin/sh and /bin/dash.
	# This is better here than `if [[ $- == *i* ]]; then...`, because executing `bash -i`, will break this.
	# Both are more reliable than checking `if [ -z "$PS1" ]; then...`, which is not always guaranteed.
	# It's effectively the same as using `tty -s` and checking the exit code, but does not require /bin/tty.
	# https://www.gnu.org/software/bash/manual/bash.html#Interactive-Shells-1
	# https://www.gnu.org/software/bash/manual/bash.html#Bash-Conditional-Expressions-1
	PrintSkippingFirmware
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
