#!/bin/bash

# MIT License

# Install stubby + quad9 + dns over tls
# This uses the NetworkManager system service via nmcli to configure DNS instead of relying on systemd-resolved + resolvectl
# Kali uses NetworkManager by default to manage resolve.conf. Ubuntu's symlink at /etc/resolv.conf is replaced with a static text file.
# Tested on Ubuntu 22.04, Kali 2023.3
# https://support.quad9.net/hc/en-us/articles/4409217364237
# https://www.blackhillsinfosec.com/the-dns-over-https-doh-mess/

#shellcheck disable=SC2034

RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings
BLUE="\033[01;34m"     # Information
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

# Get the default network interface device name, and all other network interface device names
DEV_NAME="$(ip a | grep -P "^\d:" | awk -F ': ' '{print $2}' | grep -P "^e\w+0\b")"
DEV_LIST="$(ip a | grep -P "^\d:" | awk -F ': ' '{print $2}')"

# Get the device connection profile name via nmcli
CONN_NAME="$(nmcli device show "$DEV_NAME" | grep 'GENERAL.CONNECTION:' | awk -F ':' '{ print $2 }' | sed 's/^[[:space:]]\+//g')"

function ConfigureNetworking() {

	# Add the system hostname to /etc/hosts if it's not already listed
	if ! (grep "$(hostname)" /etc/hosts > /dev/null); then
		echo ""
		echo -e "[${BLUE}*${RESET}]${BOLD}Adding hostname to /etc/hosts...${RESET}"
		echo "127.0.1.1 $(hostname)" | sudo tee -a /etc/hosts
	fi

	# Get the default network interface device name
	echo ""
	echo -e "[${BLUE}*${RESET}]${BOLD}Detecting network interfaces...${RESET}"
	echo "$DEV_LIST"
	echo ""
	echo -e "[${BLUE}>${RESET}]${BOLD}Which is the default network device?${RESET}"
	until [[ $DEV_CHOICE =~ ^([[:alnum:]]+)$ ]]; do
		read -rp "Device: " -e -i "$DEV_NAME" DEV_CHOICE
	done

	# Update these variables, the rest of the script after this function will use these new variables if they changed
	DEV_NAME="$DEV_CHOICE"
	CONN_NAME="$(nmcli device show "$DEV_NAME" | grep 'GENERAL.CONNECTION:' | awk -F ':' '{ print $2 }' | sed 's/^[[:space:]]\+//g')"

	# Configure an IP and route, if there's no route to the public internet
	echo ""
	echo -e "[${BLUE}*${RESET}]${BOLD}Checking connectivity...${RESET}"
	if ! (ping -q -c 4 1.1.1.1); then
		# Get the IPv4 address
		echo ""
		echo -e "[${BLUE}>${RESET}]${BOLD}No working routes available. Enter a static IPv4 address for $DEV_NAME (ex: 172.20.1.119).${RESET}"
		until [[ $IP4_ADDR =~ ^((([0-9]){1,3}\.){3}([0-9]){1,3})$ ]]; do
			read -rp "IPv4: " IP4_ADDR
		done
		# Get the CIDR range
		echo ""
		echo -e "[${BLUE}>${RESET}]${BOLD}Enter a CIDR range (ex: 24).${RESET}"
		until [[ $IP4_CIDR =~ ^([1-9]|[1-2][0-9]|3[0-2])$ ]]; do
			read -rp "CIDR: " IP4_CIDR
		done
		# Get the gateway
		echo ""
		echo -e "[${BLUE}>${RESET}]${BOLD}Enter the default gateway's IPv4 address.${RESET}"
		until [[ $IP4_GATEWAY =~ ^((([0-9]){1,3}\.){3}([0-9]){1,3})$ ]]; do
			read -rp "Gateway: " IP4_GATEWAY
		done

		echo ""
		echo -e "[${BLUE}*${RESET}]${BOLD}Configuring $DEV_NAME network information...${RESET}"
		sudo ip addr flush dev "$DEV_NAME" scope global || exit 1
		#sudo ip address add "$IP4_ADDR"/"$IP4_CIDR" dev "$DEV_NAME" || exit 1
		sudo nmcli connection modify "$CONN_NAME" ipv4.addresses "$IP4_ADDR"/"$IP4_CIDR"
		#sudo ip route add default via "$IP4_GATEWAY" dev "$DEV_NAME" || exit 1
		sudo nmcli connection modify "$CONN_NAME" ipv4.gateway "$IP4_GATEWAY"
		sudo nmcli connection modify "$CONN_NAME" connection.autoconnect yes
		sudo nmcli connection modify "$CONN_NAME" ipv4.method manual
		sudo systemctl restart NetworkManager
	fi
}
ConfigureNetworking

# Temporarily add quad9's unencrypted resolvers in case DNS resolution isn't working
DNS_SERVER_IP4_1='9.9.9.9'
DNS_SERVER_IP4_2='149.112.112.112'
DNS_SERVER_IP6_1='2620:fe::fe'
DNS_SERVER_IP6_2='2620:fe::9'
echo ""
echo -e "[${BLUE}*${RESET}]${BOLD}Changing current DNS server via NetworkManager to $DNS_SERVER_IP4_1 on $DEV_NAME...${RESET}"
sudo nmcli connection modify "$CONN_NAME" ipv4.dns "$DNS_SERVER_IP4_1"
sudo systemctl restart NetworkManager

function InstallStubby() {
	# Install stubby, a DNS stub resolver
	echo ""
	echo -e "[${BLUE}*${RESET}]${BOLD}Installing stubby...${RESET}"
	sudo apt update
	sudo apt install -y stubby

	# Backup the default config, and replace it with quad9's configuration
	echo ""
	echo -e "[${BLUE}*${RESET}]${BOLD}Downloading quad9's stubby.yml config...${RESET}"
	sudo mv /etc/stubby/stubby.yml /etc/stubby/stubby.yml.bkup && \
	sudo wget -qO /etc/stubby/stubby.yml https://support.quad9.net/hc/en-us/article_attachments/4411087149453/stubby.yml

	# Check the hash of the configuration file based on a previously reviewed copy
	if (sha256sum /etc/stubby/stubby.yml | grep -qx '4feef862e416bfcf9f95052f9b5397ab2f4eff7285fc46a985ed7ddd64401856  /etc/stubby/stubby.yml'); then
		echo -e "[${GREEN}*${RESET}]${BOLD}stubby.yml checksum OK${RESET}"
	else
		echo -e "[${RED}*${RESET}]${BOLD}Bad checksum for stubby.yml. Quitting${RESET}"
		exit 1
	fi

	# Start stubby systemd service
	sudo systemctl restart stubby
	sudo systemctl enable stubby

	echo ""
	echo -e "[${BLUE}*${RESET}]${BOLD}stubby installed.${RESET}"
}
InstallStubby

# Configure the system via NetworkManager to use stubby's resolver running on localhost
echo ""
echo -e "[${BLUE}*${RESET}]${BOLD}Changing resolver from systemd-resolved to stubby on localhost via NetworkManager...${RESET}"
STUBBY_IP4='127.0.0.1'
STUBBY_IP6='::1'
sudo rm /etc/resolv.conf
echo "# This is a static file with DNS entries for a local stubby resolver
# To restore the original config, first erase this file, then symlink /run/systemd/resolve/stub-resolv.conf to /etc/resolv.conf
# sudo rm /etc/resolv.conf; sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
nameserver $STUBBY_IP4
nameserver $STUBBY_IP6" | sudo tee /etc/resolv.conf > /dev/null
sudo nmcli connection modify "$CONN_NAME" ipv4.dns "$STUBBY_IP4"
#sudo nmcli connection modify "$CONN_NAME" ipv6.dns "$STUBBY_IP6"
sudo nmcli connection modify "$CONN_NAME" connection.autoconnect yes
sudo systemctl restart NetworkManager

# Stop and disable systemd-resolved service
if (systemctl is-active systemd-resolved > /dev/null); then
	sudo systemctl stop systemd-resolved
fi
if (systemctl is-enabled systemd-resolved > /dev/null); then
	sudo systemctl disable systemd-resolved
fi

echo ""
echo -e "[${BLUE}*${RESET}]${BOLD}Checking DNS...${RESET}"

# https://support.quad9.net/hc/en-us/articles/360049913611-How-to-Confirm-You-re-Using-Quad9-Linux
if [[ "$(dig +short cname id.server.on.quad9.net.)" == '' ]]; then
	echo -e "[${YELLOW}-${RESET}]${YELLOW}NOT CONNECTED${RESET}"
else
	echo -e "[${GREEN}+${RESET}]${GREEN}CONNECTION TO QUAD9 SUCCEEDED${RESET}"
fi

echo ""
echo -e "[${BLUE}i${RESET}]${BOLD}Additionally, check: https://on.quad9.net/${RESET}"
