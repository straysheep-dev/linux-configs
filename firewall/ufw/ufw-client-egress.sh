#!/bin/bash

# Reset firewall to a baseline policy with egress filtering

# Vars
PUB_NIC="$(ip route | grep 'default' | grep -Po '(?<=dev )(\S+)' | head -1)"
GTWY="$(ip route | grep 'default' | grep -Po '(?<=via )(\S+)' | head -1)"

function isRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi
}

isRoot

function checkInterface() {
	if [[ "${PUB_NIC}" == '' ]]; then
		echo "No interfaces other than loopback available. Quitting."
		exit 1
	fi
}

checkInterface

function setFirewall() {
	ufw reset

	# remove ufw default accept rules for mDNS and upnp service discovery
	sed -i 's/^-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT$/#-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT/' /etc/ufw/before.rules
	sed -i 's/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT$/#-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT/' /etc/ufw/before.rules

	sed -i 's/^-A ufw6-before-input -p udp -d ff02::fb --dport 5353 -j ACCEPT$/#-A ufw6-before-input -p udp -d ff02::fb --dport 5353 -j ACCEPT/' /etc/ufw/before6.rules
	sed -i 's/^-A ufw6-before-input -p udp -d ff02::f --dport 1900 -j ACCEPT$/#-A ufw6-before-input -p udp -d ff02::f --dport 1900 -j ACCEPT/' /etc/ufw/before6.rules

	ufw default deny incoming
	ufw default deny outgoing
	ufw default deny routed
	ufw disable
	ufw enable
	ufw allow out on "${PUB_NIC}" to any proto tcp port 80,443
	ufw allow out on "${PUB_NIC}" to any proto udp port 53
	ufw allow out on "${PUB_NIC}" to any proto udp port 123
	ufw prepend deny out to 192.168.0.0/16
	ufw prepend deny out to 172.16.0.0/12
	ufw prepend deny out to 169.254.0.0/16
	ufw prepend deny out to 10.0.0.0/8
	ufw prepend deny out on "${PUB_NIC}" to 127.0.0.0/8
	# Check for ipv6
	if (grep -qx 'IPV6=yes' /etc/default/ufw); then
		ufw prepend deny out to fc00::/7
		ufw prepend deny out on "${PUB_NIC}" to ::1
	fi
	ufw prepend allow out on "${PUB_NIC}" to "${GTWY}"
}

setFirewall
