#!/bin/bash

# Set ufw rules to a baseline policy
# Configure client with firewall rules for all endpoints in /etc/wireguard/*.conf

PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
GTWY="$(ip route | grep default | cut -d " " -f3)"

function CheckPublicInterface() {
	if [[ "$PUB_NIC" == '' ]]; then
		echo "No public interfaces available. Quitting."
		exit 1
	fi
}

# Requires a root shell to enumerate wireguard configuration files stored in /etc/wireguard/
function IsRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi
}

function SetFirewallBase() {
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

	ufw allow out on "$PUB_NIC" to any proto udp port 53 comment "$PUB_NIC"' dns'
	ufw allow out on "$PUB_NIC" to any proto udp port 123 comment "$PUB_NIC"' ntp'
	ufw allow out on "$PUB_NIC" to any proto tcp port 22 comment "$PUB_NIC"' ssh'
	ufw allow out on "$PUB_NIC" to any proto tcp port 80,443,853 comment "$PUB_NIC"

  	ufw prepend deny out to 192.168.0.0/16
	ufw prepend deny out to 172.16.0.0/12
	ufw prepend deny out to 169.254.0.0/16
	ufw prepend deny out to 10.0.0.0/8
	ufw prepend deny out on "$PUB_NIC" to 127.0.0.0/8
	# Check for ipv6
	if (grep -qx 'IPV6=yes' /etc/default/ufw); then
		ufw prepend deny out to fc00::/7
		ufw prepend deny out on "$PUB_NIC" to ::1
	fi
	ufw prepend allow out on "$PUB_NIC" to "${GTWY}" comment "$PUB_NIC"' gateway'
}

function SetFirewallWG() {

	# Check for Wireguard configuration files, silently continue otherwise
	if [ -e /etc/wireguard ]; then
		# Using '/etc/wireguard/*.conf' exactly is required to match the interface names based on the file using "${file:15:-5}" below
		for file in /etc/wireguard/*.conf; do
			# Wireguard interface name can be anything ending in .conf
			if ! (echo "$file" | grep -Pq "^.+\.conf$"); then
				echo "[i]$file filename must be in the format of: <interface>.conf"
			else
				if [ -e "$file" ]; then
					# Match any valid IPv4|6 addresses
					ENDPOINTS4="$(grep 'Endpoint' "$file" | grep -oP "(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | sort -u)"
					ENDPOINTS6="$(grep 'Endpoint' "$file" | grep -oP "([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4}" | sort -u)"

					# Use only private address ranges for DNS
					WG_DNS4="$(grep 'DNS' "$file" | grep -oP "((10|172\.(1[6-9]|2[0-9]|3[0-1])|192\.168))(\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2,3}" | sort -u)"
					WG_DNS6="$(grep 'DNS' "$file" | grep -oP "((f[c-d])([a-f0-9]{2}))(:|::)([a-f0-9]{1,4}(:|::)){0,6}[a-f0-9]{1,4}" | sort -u)"

					WG_NIC="${file:15:-5}"
				else
					exit 0
				fi

				# Add endpoints
				# No double quotes "" in for loops like $ENDPOINT4/6 as each value of $ENDPOINT4/6 needs to be invoked separately, not as a single string, see `info bash` QUOTING
				for ip in $ENDPOINTS4; do

					ufw allow out on "$PUB_NIC" to "$ip" comment "$WG_NIC"' endpoint'

					# for loop handles multiple DNS servers
					for dns in $WG_DNS4; do
						# prepend DNS rules if all private address ranges are egress filtered
						ufw prepend allow out on "$WG_NIC" to "$dns" proto udp port 53 comment "$WG_NIC"' dns'
					done

					ufw allow out on "$WG_NIC" to any proto udp port 123 comment "$WG_NIC"' ntp'
					ufw allow out on "$WG_NIC" to any proto tcp port 80,443,853 comment "$WG_NIC"
				done

				for ip in $ENDPOINTS6; do

					ufw allow out on "$PUB_NIC" to "$ip" comment "$WG_NIC"' endpoint'

					# for loop handles multiple DNS servers
					for dns in $WG_DNS6; do
						# prepend DNS rules if all private address ranges are egress filtered
						ufw prepend allow out on "$WG_NIC" to "$dns" proto udp port 53 comment "$WG_NIC"' dns'
					done

					ufw allow out on "$WG_NIC" to any proto udp port 123 comment "$WG_NIC"' ntp'
					ufw allow out on "$WG_NIC" to any proto tcp port 80,443,853 comment "$WG_NIC"
				done
			fi
		done
	fi
}

CheckPublicInterface
IsRoot
SetFirewallBase
SetFirewallWG
