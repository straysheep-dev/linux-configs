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

function ConfigureFirefoxAppArmor() {
	# Ensure other apparmor utilities are installed
	sudo apt update
	sudo apt install -y apparmor-utils apparmor-profiles apparmor-profiles-extra

	# Ensure firefox's apparmor profile is enabled
	if [[ -e /etc/apparmor.d/disable/usr.bin.firefox-esr ]]; then
		sudo rm /etc/apparmor.d/disable/usr.bin.firefox-esr
	fi

	# These configuration files need to be available locally
	sudo cp ../apparmor/apparmor-usr.bin.firefox-esr /etc/apparmor.d/usr.bin.firefox-esr
	sudo cp ../apparmor/apparmor-firefox.abstractions /etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox-esr
	sudo cp ../apparmor/apparmor-usr.bin.firefox.local /etc/apparmor.d/local/usr.bin.firefox-esr

	if ! (systemctl is-active apparmor); then
		sudo systemctl enable apparmor.service && sudo systemctl start apparmor.service
		echo -e "${BLUE}[i]${RESET}Enabling apparmor.service..."
	fi

	sudo apparmor_parser -r /etc/apparmor.d/usr.bin.firefox-esr

	echo -e "${BLUE}[i]${RESET}AppArmor Status:"
	sudo aa-status | grep -i 'firefox'
}

ConfigureFirefoxAppArmor
