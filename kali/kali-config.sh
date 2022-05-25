#!/bin/bash

# Applies apparmor to firefox-esr, and configures intrusion detection tools (rkhunter, aide)

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

AA_FIREFOX='usr.bin.firefox-esr'
AA_DIR='/etc/apparmor.d/'
AA_FIREFOX_PATH="/etc/apparmor.d/$AA_FIREFOX"
AA_FIREFOX_BROWSERS_PATH='/etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox-esr'
AA_FIREFOX_LOCAL_PATH='/etc/apparmor.d/local/usr.bin.firefox-esr'
RKHUNTER_CONF='/etc/rkhunter.conf'
AIDE_CONF='/etc/aide/aide.conf'

if [ "${EUID}" -eq 0 ]; then
	echo "You need to run this script as a normal user. Quitting."
	exit 1
fi

function ConfigureAppArmor() {
	echo "======================================================================"
	echo -e "${BLUE}[i]${RESET}Checking Firefox AppArmor profile..."

	# Ensure other apparmor utilities are installed
	sudo apt install -y apparmor-utils apparmor-profiles apparmor-profiles-extra

	# For latest firefox apparmor profile:
	# https://bazaar.launchpad.net/~mozillateam/firefox/firefox.focal/view/head:/debian/usr.bin.firefox.apparmor.14.10

	# Ensure firefox's apparmor profile is enabled
	if [[ -e "$AA_DIR"/disable/"$AA_FIREFOX" ]]; then
		sudo rm "$AA_DIR"/disable/"$AA_FIREFOX"
	fi

	# /etc/apparmor.d/usr.bin.firefox-esr
	if ! [ -e "$AA_FIREFOX_PATH" ]; then
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/apparmor/apparmor-usr.bin.firefox-esr' | sudo tee "$AA_FIREFOX_PATH"
		if ! (sha256sum "$AA_FIREFOX_PATH" | grep "eb3f9e1632e7717d5ce2eea64cbc0af43a6131345d47946a6991300a47b5a85b  $AA_FIREFOX_PATH"); then
			echo -e "${RED}[x]Bad checksum. Quitting...${RESET}"
			exit 1
		else
			echo -e "${GREEN}[OK] $AA_FIREFOX_PATH${RESET}"
		fi
	fi

	# /etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox-esr
	if ! [ -e "$AA_FIREFOX_BROWSERS_PATH" ]; then
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/apparmor/apparmor-firefox.abstractions' | sudo tee "$AA_FIREFOX_BROWSERS_PATH"
		if ! (sha256sum "$AA_FIREFOX_BROWSERS_PATH" | grep "e712b2f363663db162c804ee57d8e3e6ef983d3f0caa2dea69974d3edc086c7e  $AA_FIREFOX_BROWSERS_PATH"); then
			echo -e "${RED}[x]Bad checksum. Quitting...${RESET}"
			exit 1
		else
			echo -e "${GREEN}[OK] $AA_FIREFOX_BROWSERS_PATH${RESET}"
		fi
	fi

	# /etc/apparmor.d/local/usr.bin.firefox-esr
	if ! [ -e "$AA_FIREFOX_LOCAL_PATH" ]; then
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/apparmor/apparmor-usr.bin.firefox.local' | sudo tee "$AA_FIREFOX_LOCAL_PATH"
		if ! (sha256sum "$AA_FIREFOX_LOCAL_PATH" | grep "bcfa36de8bfc0f6063beb107bdf98af515f40fea53a7bca249658d21a0d2234a  $AA_FIREFOX_LOCAL_PATH"); then
			echo -e "${RED}[x]Bad checksum. Quitting...${RESET}"
			exit 1
		else
			echo -e "${GREEN}[OK] $AA_FIREFOX_LOCAL_PATH${RESET}"
		fi
	fi

	if ! (systemctl is-active apparmor); then 
		sudo systemctl enable apparmor.service && sudo systemctl start apparmor.service
		echo -e "${BLUE}[i]${RESET}Enabling apparmor.service..."
	fi

	sudo apparmor_parser -r "$AA_FIREFOX_PATH"
	
	echo -e "${BLUE}[i]${RESET}AppArmor Status:"
	sudo aa-status | grep -i 'firefox'
}

function ConfigureRkhunter() {

	echo "======================================================================"
	echo -e "${BLUE}[i]${RESET}Configuring rkhunter..."

	sudo apt install -y rkhunter
	
	sudo cp -n /etc/rkhunter.conf{,.bkup}
	curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/rkhunter/rkhunter.conf' | sudo tee "$RKHUNTER_CONF" > /dev/null
	if ! (sha256sum "$RKHUNTER_CONF" | grep "c4025f9e0268a016351bef1a7b64f6349a64f419ef0f025a7b6f181ef18fff66  $RKHUNTER_CONF"); then
		echo -e "${RED}[x]Bad checksum. Quitting...${RESET}"
		exit 1
	else
		echo -e "${GREEN}[OK] $RKHUNTER_CONF${RESET}"
	fi
	
	if (sudo rkhunter -C); then
		echo -e "${BLUE}[i]${RESET}Updating rkhunter database..."
		sudo rkhunter --propupd
	else
		echo -e "${RED}[ERROR] reading $RKHUNTER_CONF, quitting.${RESET}"
	fi
}

function ConfigureAIDE() {

	echo "======================================================================"
	echo -e "${BLUE}[i]${RESET}Configuring aide..."

	sudo apt install -y aide
	
	sudo cp -n /etc/rkhunter.conf{,.bkup}
	curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/aide/aide-0.17.3.conf' | sudo tee "$AIDE_CONF" > /dev/null
	if ! (sha256sum "$AIDE_CONF" | grep "33bf09c5b04a7a795db5f8318862c447e3d938eb46ef9cc8d5a042bf81aa07a7  $AIDE_CONF"); then
		echo -e "${RED}[x]Bad checksum. Quitting...${RESET}"
		exit 1
	else
		echo -e "${GREEN}[OK] $AIDE_CONF${RESET}"
	fi
	if (sudo aide -D -c "$AIDE_CONF"); then
		sudo aide --init -c "$AIDE_CONF"
		echo -e "${BLUE}[i]${RESET}Installing aide database..."
		sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
	else
		echo -e "${RED}[ERROR] reading $RKHUNTER_CONF, quitting.${RESET}"
	fi
	
	echo -e "${BLUE}[✓]${RESET}Done."
}

# Functions
ConfigureAppArmor
ConfigureRkhunter
ConfigureAIDE
