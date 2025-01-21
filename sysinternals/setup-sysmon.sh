#!/bin/bash

# shellcheck disable=SC2034

# MIT License
# Copyright (c) 2023, straysheep-dev
# Copyright (c) Microsoft Corporation.
# https://github.com/Sysinternals/ProcMon-for-Linux/blob/main/LICENSE

# Install Sysmon on Linux (currently only for Ubuntu 20.04+)

# https://github.com/Sysinternals/SysmonForLinux/blob/main/INSTALL.md
# https://github.com/angristan/wireguard-install
# https://www.antisyphontraining.com/getting-started-in-security-with-bhis-and-mitre-attck-w-john-strand/

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
                echo -e "${BOLD}Run this script as a normal user. Quitting.${RESET}"
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

function InstallSysmon() {
	sudo apt-get update
	sudo apt-get install -y sysmonforlinux
}

function ConfigureSysmon() {
	# -i can optionally take a config file
	sudo sysmon -i
	echo ""
	systemctl status sysmon
}

function UninstallSysmon() {
	sudo sysmon -u force
	sudo apt autoremove --purge -y sysmonforlinux
}

function PrintExampleUsage() {
	echo -e "[${BLUE}i${RESET}]${BOLD}EXAMPLE USAGE:${RESET}"
	echo -e "	${BLUE}https://github.com/Sysinternals/SysmonForLinux#output${RESET}"
	echo -e "	[Terminal 1]: sudo tail -f /var/log/syslog | sudo /opt/sysmon/sysmonLogView | grep bashrc"
	echo -e "	[Termianl 2]: echo '#reverse-shell-goes-here' | tee -a ~/.bashrc"
	echo -e ""
	echo -e "	[Terminal 1]: sudo tail -f /var/log/syslog | sudo /opt/sysmon/sysmonLogView | grep '::1'"
	echo -e "	[Terminal 2]: nc -nvlp 8080 -s ::1"
}


# Management Menu
echo -e "   ${BLUE}What would you like to do?${RESET}"
echo -e ""
echo -e "   ${BOLD}1) Install / Start Sysmon${RESET}"
echo -e "   ${BOLD}2) Uninstall Sysmon${RESET}"
echo -e "   ${BOLD}3) Print Example Usage${RESET}"
echo -e "   ${BOLD}4) Exit${RESET}"
echo -e ""
until [[ $MENU_CHOICE =~ ^[1-4]$ ]]; do
	read -rp "Enter [1/2/3/4]: " -e MENU_CHOICE
done
if [[ $MENU_CHOICE == "1" ]]; then
	if (command -v sysmon > /dev/null) && ! (systemctl is-active sysmon > /dev/null); then
		echo -e "[${BLUE}>${RESET}]${BOLD}Starting Sysmon...${RESET}"
		ConfigureSysmon
	elif (command -v sysmon > /dev/null); then
		echo -e "[${BLUE}*${RESET}]${BOLD}Sysmon already installed and running.${RESET}"
		exit
	else
		echo -e "[${BLUE}>${RESET}]${BOLD}Installing Sysmon...${RESET}"
		AddMicrosoftKey
		AddMicrosoftFeed
		InstallSysmon
		ConfigureSysmon
	fi
elif  [[ $MENU_CHOICE == "2" ]]; then
	if ! (command -v sysmon > /dev/null); then
		echo -e "[${BLUE}i${RESET}]${BOLD}Sysmon not installed. Quitting.${RESET}"
		exit
	else
		echo -e "[${BLUE}>${RESET}]${BOLD}Stopping and uninstalling Sysmon...${RESET}"
		UninstallSysmon
	fi
elif [[ $MENU_CHOICE == "3" ]]; then
	PrintExampleUsage
elif [[ $MENU_CHOICE == "4" ]]; then
	exit
fi

