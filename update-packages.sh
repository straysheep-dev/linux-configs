#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 straysheep-dev

# shellcheck disable=SC2034

# Run this weekly or daily as part of normal system maintenance. Be sure to shutdown all
# VMs on Proxmox before automating reboots.
#
# Cron Example (run as root) for daily updates at 3a local time, reboot at 4a if needed:
# m h  dom mon dow   command
# 0 3 * * * /bin/bash /usr/local/bin/update-packages.sh
# 0 4 * * * /bin/bash -c 'if [[ -e /run/reboot-required ]]; then sudo systemctl reboot; fi'
#
# For systemd-timer examples: https://github.com/straysheep-dev/ansible-role-configure_updates

# Exit any pipeline failure with a non-zero exit code
set -euo pipefail

# ANSI-C quoting is valid, but it's a bash-only extension
# To practice portability, we'll mimic the suggested alternatives
# https://www.shellcheck.net/wiki/SC3003
BLUE="\033[01;34m"
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
RED="\033[01;31m"
BOLD="\033[01;01m"
RESET="\033[00m"

# printf is more portable and predictable than echo
# https://www.shellcheck.net/wiki/SC2059
# https://pubs.opengroup.org/onlinepubs/9799919799/utilities/echo.html#
# https://pubs.opengroup.org/onlinepubs/9799919799/utilities/printf.html
function PrintUpdatingSystemPackages() {
	printf "[%b>%b] %bUpdating all system packages...%b\n" "${BLUE}" "${RESET}" "${BOLD}" "${RESET}"
}
function PrintUpdatingSnapPackages() {
	printf "[%b>%b] %bUpdating all snap packages...%b\n" "${BLUE}" "${RESET}" "${BOLD}" "${RESET}"
}
function PrintUpdatingFlatpakApps() {
	printf "[%b>%b] %bUpdating all flatpak applications...%b\n" "${BLUE}" "${RESET}" "${BOLD}" "${RESET}"
}
function PrintUpdatingFirmware() {
	printf "[%b>%b] %bChecking for available firmware updates...%b\n" "${BLUE}" "${RESET}" "${BOLD}" "${RESET}"
}
function PrintFwupdVersionInfo() {
	printf "[%b*%b] fwupd version %b%s%b is lower than the minimum required version (%b%s%b).\n" "${BLUE}" "${RESET}" "${BOLD}" "${FWUPD_VERSION}" "${RESET}" "${BOLD}" "${FWUPD_MIN_VERSION}" "${RESET}"
}
function PrintSkippingFirmware() {
	printf "[%b*%b] %bSkipping firmware updates, detected incompatible system or non-interactive session...%b\n" "${YELLOW}" "${RESET}" "${BOLD}" "${RESET}"
}
function PrintUpdatingSystemPackagesError() {
	printf "[%b*%b] %bPackage manager not detected. Exiting.%b\n" "${RED}" "${RESET}" "${BOLD}" "${RESET}"
}

# Must be run as root
if [[ "$EUID" -ne 0 ]]; then
	printf "[%b*%b]Must be run as %broot%b. Exiting.\n" "${YELLOW}" "${RESET}" "${RED}" "${RESET}"
	exit 1
fi

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

if grep -Pqx '^ID=kali$' /etc/os-release; then
	PrintUpdatingSystemPackages
	apt update -q
	DEBIAN_FRONTEND=noninteractive \
	NEEDRESTART_MODE=a \
	apt full-upgrade -yq \
	-o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
	apt autoremove --purge -yq
	apt-get clean
elif command -v pveversion > /dev/null; then
	PrintUpdatingSystemPackages
	apt-get update -q
	DEBIAN_FRONTEND=noninteractive \
	NEEDRESTART_MODE=a \
	apt-get dist-upgrade -yq \
	-o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
	apt autoremove --purge -yq
	apt-get clean
elif command -v apt > /dev/null; then
	PrintUpdatingSystemPackages
	apt update -q
	DEBIAN_FRONTEND=noninteractive \
	NEEDRESTART_MODE=a \
	apt full-upgrade -yq \
	-o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
	apt autoremove --purge -yq
	apt-get clean
elif command -v dnf > /dev/null; then
	PrintUpdatingSystemPackages
	dnf upgrade -yq
	dnf autoremove -yq
	dnf clean all
else
	PrintUpdatingSystemPackagesError
	exit 1
fi

if command -v snap > /dev/null; then
	PrintUpdatingSnapPackages
	snap refresh
fi

if command -v flatpak > /dev/null; then
	PrintUpdatingFlatpakApps
	# Automating updates through flatpak has some risk. See the post the Arch Linux Wiki points to.
	# https://wiki.archlinux.org/title/Flatpak#Automatic_updates_via_systemd
	# Applications can gain new permissions that you may not have a preconfigured setting for.
	# This needs reviewed.
	flatpak update --noninteractive --assumeyes
fi

if [ -e /proc/device-tree/compatible ]; then
	# Check Raspberry Pi model and CPU across distributions (better than /proc/cpuinfo)
	# https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#best-practices-for-revision-code-usage
	if tr '\0' '\n' < /proc/device-tree/compatible | grep -iq 'raspberrypi'; then
		PrintSkippingFirmware
		# TODO: Check Raspberry Pi firmware update methods
	fi
elif command -v systemd-detect-virt > /dev/null && systemd-detect-virt --quiet; then
	# Detect execution in a virtualized environment, this also works on containers
	PrintSkippingFirmware
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
	# sort -V can perform a natural sorting of version numbers within text.
	# if the we match on our minimum version, we know the running version is higher.
	if command -v fwupdmgr > /dev/null; then
		FWUPD_MIN_VERSION='1.8.0'
		FWUPD_VERSION="$(fwupdmgr --version 2>/dev/null | awk '/^runtime\s+org.freedesktop.fwupd\s+/{print $3}')"
		FWUPD_LOWEST_VERSION="$(printf '%s\n' "${FWUPD_MIN_VERSION}" "${FWUPD_VERSION}" | sort -V | head -1)"
		if [[ "${FWUPD_LOWEST_VERSION}" == "${FWUPD_MIN_VERSION}" ]]; then
			PrintUpdatingFirmware
			fwupdmgr get-updates && \
			fwupdmgr update
		else
			PrintFwupdVersionInfo
			PrintSkippingFirmware
		fi
	fi
fi
