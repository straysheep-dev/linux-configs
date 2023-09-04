#!/bin/bash

# Installs unbound dns server
# Tested on:
# - Ubuntu 20.04+
# - Kali 2023.3

RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings
BLUE="\033[01;34m"     # Information
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

function InstallUnbound() {

	if ! (command -v unbound > /dev/null); then
		echo "======================================================================"
		echo -e "${BLUE}[i]${RESET}Install Unbound?"
		echo ""
		until [[ $UNBOUND_CHOICE =~ ^(y|n)$ ]]; do
			read -rp "[y/n]: " UNBOUND_CHOICE
		done
		if [[ $UNBOUND_CHOICE == "y" ]]; then
			sudo apt install -y unbound

			if ! (sudo unbound-checkconf | grep 'no errors'); then
				echo -e "${RED}[i]${RESET}Error with unbound configuration. Quitting."
				echo -e "${RED}[i]${RESET}Address any configuration errors above then re-run this script."
				exit 1
			else
				echo -e "${BLUE}[>]${RESET}Stopping and disabling systemd-resolved service..."
				if (systemctl is-active systemd-resolved); then
					sudo systemctl stop systemd-resolved
				fi
				if (systemctl is-enabled systemd-resolved); then
					sudo systemctl disable systemd-resolved
				fi

				# Apply latest conf and restart
				sudo systemctl restart unbound
				sudo systemctl enable unbound

				sleep 2

				if ! (grep -Eq "^nameserver[[:space:]]127.0.0.1$" /etc/resolv.conf); then
					echo -e "${YELLOW}[>]${RESET}Pointing /etc/resolv.conf to unbound on 127.0.0.1..."
					sudo sed -i 's/^nameserver[[:space:]]127.0.0.53/nameserver 127.0.0.1/' /etc/resolv.conf || exit 1
				fi
			fi
		fi
	fi
}

function ApplyConfigFiles() {

	UNBOUND_CONF_PATH='/etc/unbound'

	for file in "$UNBOUND_CONF_PATH"/unbound.conf.d/*.conf; do
		echo -e "${RED}[>]${RESET}Removing $file..."
		sudo rm -f "$file"
	done

  # Takes the default unbond.conf file
	for file in ./unbound.conf; do
		echo -e "${BLUE}[>]${RESET}Installing $file..."
		sudo cp "$file" "$UNBOUND_CONF_PATH"/
	done

  # Assumes any additional config files are named unbound-<something>.conf
	for file in ./unbound-*.conf; do
		echo -e "${BLUE}[>]${RESET}Installing $file..."
		sudo cp "$file" "$UNBOUND_CONF_PATH"/unbound.conf.d/
	done

	if (sudo unbound-checkconf | grep 'no errors'); then
		sudo systemctl restart unbound
		sleep 2
		systemctl status unbound
	fi

}

InstallUnbound
ApplyConfigFiles

echo ""
echo -e "${YELLOW}[i]${RESET}Review your network manager's DNS settings, and reboot."
echo -e "Review DNS with:"
echo -e "  - Wireshark / tcpdump outbound port 53"
echo -e "  - syslog / journalctl -f | grep 'unbound'"
echo -e "${BLUE}[*]${RESET}Done."
