#!/bin/bash

# pcap as a service, capture network data for later processing with tools like Zeek and RITA

# GPL-3.0-or-later

# Works with:
# - Ubuntu
# - pfSense (to do)

# This script was built from the following exmaples:
# https://github.com/0ptsec/optsecdemo
# https://github.com/bettercap/bettercap/blob/master/bettercap.service
# https://github.com/angristan/wireguard-install
# https://github.com/g0tmi1k/os-scripts/blob/master/kali2.sh

# Additional resources:
# https://github.com/zeek/zeek
# https://github.com/activecm/rita

# Thanks and credits:
# https://github.com/william-stearns (wstearns-ACM) in the Threat Hunter Community Discord

RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings
BLUE="\033[01;34m"     # Information
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

function IsRoot() {

	# Root EUID check
	if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi

}
IsRoot

function checkOS() {

	# Check OS version
	OS="$(grep -E "^ID=" /etc/os-release | cut -d '=' -f 2)"
	if [[ "$OS" == '' ]]; then
		OS="$(cat /etc/platform)"
		if [[ "$OS" == pfSense ]]; then
			echo -e "[${BLUE}i${RESET}]$OS detected."
		fi
		exit 1
	elif [[ $OS == "ubuntu" ]]; then
		CODENAME="$(grep VERSION_CODENAME /etc/os-release | cut -d '=' -f 2)" # debian or ubuntu
		echo -e "[${BLUE}i${RESET}]$OS $CODENAME detected."
		MAJOR_UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2 | cut -d '.' -f 1)
		if [[ $MAJOR_UBUNTU_VERSION -lt 18 ]]; then
			echo "⚠️ Your version of Ubuntu is not supported."
			echo ""
			echo "However, if you're using Ubuntu >= 16.04 or beta, then you can continue, at your own risk."
			echo ""
			until [[ $CONTINUE =~ ^(y|n)$ ]]; do
				read -rp "Continue? [y/n]: " -e CONTINUE
			done
			if [[ $CONTINUE == "n" ]]; then
				exit 1
			fi
		fi
	elif [[ $OS == "fedora" ]]; then
		MAJOR_FEDORA_VERSION="$(grep VERSION_ID /etc/os-release | cut -d '=' -f2)"
		echo -e "[${BLUE}i${RESET}]$OS $MAJOR_FEDORA_VERSION detected."
		if [[ $MAJOR_FEDORA_VERSION -lt 34 ]]; then
			echo "⚠️ Your version of Fedora may not be supported."
			echo ""
			until [[ $CONTINUE =~ ^(y|n)$ ]]; do
				read -rp "Continue? [y/n]: " -e CONTINUE
			done
			if [[ $CONTINUE == "n" ]]; then
				exit 1
			fi
		fi
		exit 1
	fi
}
checkOS

# Check to see if this service is already running
if [ -e /etc/systemd/system/packet-capture.service ]; then
	systemctl status packet-capture.service
	echo ""
	echo -e "[${BLUE}i${RESET}]Service already exists. Reconfigure and overwrite it?"
	until [[ $RECONFIGURE_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "[y/n]: " -e -i y RECONFIGURE_CHOICE
	done
	if [ "$RECONFIGURE_CHOICE" == y ]; then
		if (systemctl is-active packet-capture.service > /dev/null); then
			systemctl stop packet-capture.service
		fi
		if (systemctl is-enabled packet-capture.service > /dev/null); then
			systemctl disable packet-capture.service
		fi
		rm /etc/systemd/system/packet-capture.service && \
		rm /etc/cron.d/pcap-rotation-service && \
		systemctl daemon-reload
	else
		exit 0
	fi
fi

function DefinePCAPPath() {
	echo ""
	echo -e "[${BLUE}>${RESET}]Please enter a path for pcap storage (default is ${GREEN}/opt/pcaps${RESET})"
	echo ""
	until [[ $PCAP_PATH =~ ^(/[a-zA-Z0-9_-]+){1,}$ ]]; do
		read -rp "[Enter full path without the trailing '/']: " -e -i '/opt/pcaps' PCAP_PATH
	done

	if [ "$PCAP_PATH" == '' ]; then
		if ! [ -e /opt/pcaps ]; then
			echo -e "[${GREEN}>${RESET}]Creating /opt/pcaps..."
			mkdir -p /opt/pcaps
		else
			echo -e "[${GREEN}✓${RESET}]/opt/pcaps already exits."
		fi
	else
		if ! [ -e "$PCAP_PATH" ]; then
			echo -e "[${GREEN}>${RESET}]Creating $PCAP_PATH..."
			mkdir "$PCAP_PATH"
		else
			echo -e "[${GREEN}✓${RESET}]$PCAP_PATH exists."
		fi
	fi
}
DefinePCAPPath

function DefineNIC() {
	# Select network interface
	CAP_IFACE="$(ip a | grep -oP "^\d+:\s+\w+:" | cut -d ':' -f 2 | sed 's/[[:space:]]//g' | grep -P "^e\w+")"

	echo ""
	echo -e "[${BLUE}i${RESET}]Detecting network interfaces..."
	ip a | grep -oP "^\d+:\s+\w+:" | cut -d ':' -f 2 | sed 's/[[:space:]]//g'
	echo ""
	echo -e "[${BLUE}i${RESET}]Which interface would you like to capture from?"
	until [[ $CAP_IFACE_CHOICE =~ ^([[:alnum:]]+)$ ]]; do
		read -rp "Interface: " -e -i "$CAP_IFACE" CAP_IFACE_CHOICE
	done
}
DefineNIC

function SchedulePCAPRotation() {
	# Create a cron task to rotate pcap files based on logging time frame
	echo ""
	echo -e "[${BLUE}i${RESET}]Please enter a range of time in days for logs to maintain."
	echo "   Cron will run daily (/etc/cron.d/pcap-rotation-service) to rotate the pcaps."
	echo ""
	until [[ $DAYS =~ ^([[:digit:]]+)$ ]]; do
		read -rp "Range of time (days): " -e -i 30 DAYS
	done
	echo "# Cron task for packet-capture.service
# Rotates pcap files under $PCAP_PATH based on the range of time in days
# For example, +60 means 60 days of pcaps are maintained

* 0  * * * root /usr/bin/find $PCAP_PATH -mtime +$DAYS -delete" >> /etc/cron.d/pcap-rotation-service

	echo -e "${GREEN}[>]${RESET}Added task to /etc/cron.d/pcap-rotation-service"
}
SchedulePCAPRotation

# cat /etc/systemd/system/packet-capture.service
echo "[Unit]
Description=Packet capture service for network forensics
Documentation=https://github.com/straysheep-dev/network-visibility, https://www.activecountermeasures.com/raspberry-pi-network-sensor-webinar-qa/
Wants=network.target
After=network.target

[Service]
Type=simple
PermissionsStartOnly=true
ExecStart=/usr/bin/nice -n 15 /usr/sbin/tcpdump -i $CAP_IFACE_CHOICE -Z nobody -G 3600 -w '$PCAP_PATH/$(hostname -s).%%Y%%m%%d%%H%%M%%S.pcap' '((tcp[13] & 0x17 != 0x10) or not tcp)'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/packet-capture.service

# tcpdump still drops privileges, will restart automatically
# use %% to escape %'s in systemd service units
# root:root /opt/pcaps
# tcpdump:tcpdump /opt/pcaps/hostname.%%Y%%m%%d%%H%%M%%S.pcap
# $(subshell) is encased within two double quotes ""'s to safely handle 'hostname -s'

echo ""
echo -e "[${BLUE}i${RESET}]Reloading all systemctl service files..."
echo ""
systemctl daemon-reload && \
echo -e "[${BLUE}i${RESET}]Enabling packet-capture.service..."
echo ""
systemctl enable packet-capture.service && \
echo -e "[${BLUE}i${RESET}]Starting packet-capture.service"
echo ""
systemctl start packet-capture.service && \
echo -e "[${GREEN}✓${RESET}]Done."
echo ""
systemctl status packet-capture.service
