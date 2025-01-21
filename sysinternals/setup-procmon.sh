#!/bin/bash

# shellcheck disable=SC2034

# MIT License
# Copyright (c) 2023, straysheep-dev
# Copyright (c) Microsoft Corporation.
# https://github.com/Sysinternals/ProcMon-for-Linux/blob/main/LICENSE

# Install ProcMon on Linux (currently only for Ubuntu 20.04+)

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

OS_ID="$(grep '^ID=' /etc/os-release | cut -d '=' -f 2)"
OS_VERSION="$(lsb_release -rs)"

function isRoot() {
        if [ "${EUID}" -eq 0 ]; then
                echo "Run this script as a normal user. Quitting."
                exit 1
        fi
}

isRoot

function AddMicrosoftKey() {
	# https://packages.microsoft.com/
	# https://docs.microsoft.com/en-us/windows-server/administration/linux-package-repository-for-microsoft-software#package-and-repository-signing-key
	# Microsoft's GPG public key may be downloaded here: https://packages.microsoft.com/keys/microsoft.asc
	# Public Key ID: Microsoft (Release signing) gpgsecurity@microsoft.com
	# Public Key Fingerprint: BC52 8686 B50D 79E3 39D3 721C EB3E 94AD BE12 29CF

	if ! [ -e /etc/apt/trusted.gpg.d/microsoft.gpg ]; then

		# /etc/apt/trusted.gpg.d/microsoft.gpg
		# pub   rsa2048/0xEB3E94ADBE1229CF 2015-10-28 [SC]
		#       Key fingerprint = BC52 8686 B50D 79E3 39D3  721C EB3E 94AD BE12 29CF
		# uid                             Microsoft (Release signing) <gpgsecurity@microsoft.com>

		# Method from: https://github.com/Sysinternals/SysmonForLinux/blob/main/INSTALL.md
		# Example: https://learn.microsoft.com/en-us/windows-server/administration/linux-package-repository-for-microsoft-software#examples
		# It appears both asc and gpg format for the key will work fine
		wget -q -O - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
		sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/
		sudo chown root:root /etc/apt/trusted.gpg.d/microsoft.gpg
		sudo chmod 644 /etc/apt/trusted.gpg.d/microsoft.gpg
	fi
	if ! (gpg /etc/apt/trusted.gpg.d/microsoft.gpg 2>/dev/null | grep -P "BC52(\s)?8686(\s)?B50D(\s)?79E3(\s)?39D3(\s+)?721C(\s)?EB3E(\s)?94AD(\s)?BE12(\s)?29CF"); then
		echo -e "${RED}BAD SIGNATURE${RESET}"
		exit
	else
		echo -e "[${GREEN}OK${RESET}]"
	fi
}

function AddMicrosoftFeed() {
	# https://github.com/Sysinternals/SysmonForLinux/blob/main/INSTALL.md
	# This takes the steps from Debian's installation instructions so we can check the gpg key signature before installing anything
	if ! [ -e /etc/apt/sources.list.d/microsoft-prod.list ]; then
		wget -q https://packages.microsoft.com/config/"$OS_ID"/"$OS_VERSION"/prod.list
		sudo mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
		sudo chown root:root /etc/apt/sources.list.d/microsoft-prod.list
		sudo chmod 644 /etc/apt/sources.list.d/microsoft-prod.list
	fi
}

function InstallProcmon() {
	sudo apt-get update
	sudo apt-get install -y procmon
}

AddMicrosoftKey
AddMicrosoftFeed
InstallProcmon
