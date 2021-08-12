#!/bin/bash

# Set ufw rules to a baseline policy for client connecting to a single endpoint
# Permit remote connections to managed servers
# Permit wireguard connections to managed servers

# Vars
PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
GTWY="$(ip route | grep default | cut -d " " -f3)"
WG="$(ip a | grep -o wg[0-9] | head -1)"

# Check for conf files, silently continue otherwise
if [ -e /etc/wireguard ]; then
	if (ls /etc/wireguard/ | grep -q "wg[0-9].conf"); then
		#ENDPOINTS4="$(grep 'Endpoint' /etc/wireguard/wg*.conf | grep -o -E "([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})" | sort -u)"
		#ENDPOINTS6="$(grep 'Endpoint' /etc/wireguard/wg*.conf | grep -o -E "(([a-f0-9]{1,4}:){1,6}:([a-f0-9]{1,4}))|(([a-f0-9]{1,4}:){7}([a-f0-9]{1,4}))" | sort -u)"
		ENDPOINTS4="$(grep 'Endpoint' /etc/wireguard/wg*.conf | cut -d ' ' -f 3 | rev | cut -d ':' -f 2- | rev | grep '\.' | sort -u)"
		ENDPOINTS6="$(grep 'Endpoint' /etc/wireguard/wg*.conf | cut -d ' ' -f 3 | rev | cut -d ':' -f 2- | rev | grep ':' | sort -u)"
	fi
fi

function isRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi
}

isRoot

function checkPublicInterface() {
	if [[ "${PUB_NIC}" == '' ]]; then
		echo "No public interfaces available. Quitting."
		exit 1
	fi
}

checkPublicInterface

function checkWgInterface() {
	# Proceed only if one interface is up
	if [[ $(ip a | grep -o "wg[0-9]" | sort -u | wc -l) == 1 ]]; then
		# Use only private address ranges, need to add 192.168/16 && 172.16/12, adjust IPv6 regex
		WG_DNS4="$(grep 'DNS' /etc/wireguard/"${WG}".conf | grep -o -E "(10\.[0-9]{1,3}\.[0-9]{1,3}\.[1])" | sort -u)"
		WG_DNS6="$(grep 'DNS' /etc/wireguard/"${WG}".conf | grep -o -E "(f[c-d]([a-f0-9]{1,2}:)([a-f0-9]{1,4}:){2,3}:)[1]" | sort -u)"
	elif [[ $(ip a | grep -o "wg[0-9]" | sort -u | wc -l) -gt 1 ]]; then
		echo "More than one wireguard interface detected. Quitting."
		exit 1
	fi
}

checkWgInterface

function setFirewall() {
	ufw reset

	# ipv4
	sed -i 's/^-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT$/#-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT/' /etc/ufw/before.rules
	sed -i 's/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT$/#-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT/' /etc/ufw/before.rules
	# ipv6
	sed -i 's/^-A ufw6-before-input -p udp -d ff02::fb --dport 5353 -j ACCEPT$/#-A ufw6-before-input -p udp -d ff02::fb --dport 5353 -j ACCEPT/' /etc/ufw/before6.rules
	sed -i 's/^-A ufw6-before-input -p udp -d ff02::f --dport 1900 -j ACCEPT$/#-A ufw6-before-input -p udp -d ff02::f --dport 1900 -j ACCEPT/' /etc/ufw/before6.rules

	ufw default deny incoming
	ufw default deny outgoing
	ufw default deny routed
	ufw disable
	ufw enable
	ufw allow out on "${PUB_NIC}" to any proto tcp port 80,443,853
	ufw allow out on "${PUB_NIC}" to any proto udp port 53
	# Add endpoints
	# No double quotes "" for $ENDPOINTS4/6 as each value needs to be invoked separately, not as a single string, see `info bash` QUOTING
	for ip in $ENDPOINTS4; do
		ufw allow out on "${PUB_NIC}" to "$ip" comment 'endpoint'
	done
	for ip in $ENDPOINTS6; do
		ufw allow out on "${PUB_NIC}" to "$ip" comment 'endpoint'
	done
  	ufw prepend deny out to 192.168.0.0/16
	ufw prepend deny out to 172.16.0.0/12
	ufw prepend deny out to 169.254.0.0/16
	ufw prepend deny out to 10.0.0.0/8
	ufw prepend deny out on "${PUB_NIC}" to 127.0.0.0/8
	# Check for ipv6
	if (grep -qx 'IPV6=yes' /etc/default/ufw); then
		ufw prepend deny out to fc00::/7
		ufw prepend deny out on "${PUB_NIC}" to ::1
		# Check for a wg interface
		if ! [[ "${WG}" == '' ]]; then
			if ! [[ "${WG_DNS6}" == '' ]]; then
				ufw prepend allow out on "${WG}" to "${WG_DNS6}" proto udp port 53 comment 'wg'
			else
				echo -e "No IPv6 Dns settings for ${WG}"
			fi
		fi
	fi
	ufw prepend allow out on "${PUB_NIC}" to "${GTWY}"
	# Check for a wg interface
	if ! [[ "${WG}" == '' ]]; then
		if ! [[ "${WG_DNS4}" == '' ]]; then
			ufw prepend allow out on "${WG}" to "${WG_DNS4}" proto udp port 53 comment 'wg'
			ufw prepend allow out on "${WG}" to any proto tcp port 80,443,853 comment 'wg'
		else
			echo -e "No IPv4 Dns settings for ${WG}"
		fi
	fi
}

setFirewall
