#!/bin/bash

# Applies apparmor to firefox[-esr]

# Firefox apparmor profile source:
# https://bazaar.launchpad.net/~mozillateam/firefox/firefox.focal/view/head:/debian/usr.bin.firefox.apparmor.14.10


BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

AA_FIREFOX='usr.bin.firefox-esr'
AA_DIR='/etc/apparmor.d/'
AA_FIREFOX_PATH="$AA_DIR/$AA_FIREFOX"
AA_FIREFOX_BROWSERS_PATH='$AA_DIR/abstractions/ubuntu-browsers.d/firefox-esr'
AA_FIREFOX_LOCAL_PATH='$AA_DIR/local/usr.bin.firefox-esr'

if [ "${EUID}" -eq 0 ]; then
	echo "You need to run this script as a normal user. Quitting."
	exit 1
fi

function ConfigureAppArmor() {
	echo ""
	echo -e "${BLUE}[>]${RESET}Checking Firefox AppArmor profile..."

	# Ensure other apparmor utilities are installed
	sudo apt update
	sudo apt install -y apparmor-utils apparmor-profiles apparmor-profiles-extra

	# Ensure firefox's apparmor profile is enabled
	if [[ -e "$AA_DIR"/disable/"$AA_FIREFOX" ]]; then
		sudo rm "$AA_DIR"/disable/"$AA_FIREFOX"
	fi

	# /etc/apparmor.d/usr.bin.firefox-esr
	sudo cp ./apparmor-usr.bin.firefox-esr' "$AA_FIREFOX_PATH"

	# /etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox-esr
	sudo cp ./apparmor-firefox.abstractions "$AA_FIREFOX_BROWSERS_PATH"

	# /etc/apparmor.d/local/usr.bin.firefox-esr
	sudo cp ./apparmor-usr.bin.firefox.local "$AA_FIREFOX_LOCAL_PATH"

	if ! (systemctl is-active apparmor); then
		sudo systemctl enable apparmor.service && sudo systemctl start apparmor.service
		echo -e "${BLUE}[i]${RESET}Enabling apparmor.service..."
	fi

	sudo apparmor_parser -r "$AA_FIREFOX_PATH"

	echo -e "${BLUE}[i]${RESET}AppArmor Status:"
	sudo aa-status | grep -i 'firefox'
}

ConfigureAppArmor
