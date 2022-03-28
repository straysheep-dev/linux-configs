#!/bin/bash

# Manage wireguard server firewall rules
# Logs wireguard client authentications to /var/log/syslog

GTWY="$(ip route | grep 'default' | grep -Po '(?<=via )(\S+)' | head -1)"
WG="$(ip a | grep -o wg[0-9] | head -1)"

SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
SERVER_WG_NIC="$(grep SERVER_WG_NIC /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_PORT="$(grep SERVER_PORT /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_IPV4="$(grep SERVER_WG_IPV4 /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_IPV6="$(grep SERVER_WG_IPV6 /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_NET4="$(grep -P "^Address" /etc/wireguard/"${SERVER_WG_NIC}".conf | grep -oP "$SERVER_WG_IPV4/\d\d" | sed 's/\.[[:digit:]]\//\.0\//')"
SERVER_WG_NET6="$(grep -P "^Address" /etc/wireguard/"${SERVER_WG_NIC}".conf | grep -oP "$SERVER_WG_IPV6/\d\d" | sed 's/:[[:digit:]]\//:\//')"
SERVER_SSH_PORT="$(grep -E "^Port ([0-9]{1,5})" /etc/ssh/sshd_config | cut -d ' ' -f 2)"

# These paths must be \ escaped to be interpretted by sed
WG_POSTUP_PATH=''
WG_POSTDOWN_PATH=''

function isRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi
}
isRoot

function installUFW() {
	if ! (command -v ufw > /dev/null); then
		apt update
		apt install -y ufw
	fi
}
installUFW

function definePaths() {
	if [[ "$WG_POSTUP_PATH" == "" ]] || [[ "$WG_POSTDOWN_PATH" == "" ]]; then
		echo "[?]Where are the PostUp.sh and PostDown.sh scripts installed?"
		echo "ufw-wg-server.sh will configure wg-quick@wg[x].service to call them."
		echo ""

		# PostUp
		until [[ $SET_POSTUP_PATH =~ ^(/[a-zA-Z0-9_-]+){1,}\.sh$ ]]; do
			read -rp "PostUp script path: " SET_POSTUP_PATH
		done
		WG_POSTUP_PATH="$(echo $SET_POSTUP_PATH | sed 's/\//\\\//g' | sed 's/\./\\./g')"
		echo "WG_POSTUP_PATH=$WG_POSTUP_PATH"

		# PostDown
		until [[ $SET_POSTDOWN_PATH =~ ^(/[a-zA-Z0-9_-]+){1,}\.sh$ ]]; do
			read -rp "PostDown script path: " SET_POSTDOWN_PATH
		done
		WG_POSTDOWN_PATH="$(echo $SET_POSTDOWN_PATH | sed 's/\//\\\//g' | sed 's/\./\\./g')"
		echo "WG_POSTDOWN_PATH=$WG_POSTDOWN_PATH"
	fi
}
#definePaths

function setFirewall() {
	ufw reset

	# Disable mDNS and UPnP
	sed -i 's/^-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT$/#-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT/' /etc/ufw/before.rules
	sed -i 's/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT$/#-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT/' /etc/ufw/before.rules

	sed -i 's/^-A ufw6-before-input -p udp -d ff02::fb --dport 5353 -j ACCEPT$/#-A ufw6-before-input -p udp -d ff02::fb --dport 5353 -j ACCEPT/' /etc/ufw/before6.rules
	sed -i 's/^-A ufw6-before-input -p udp -d ff02::f --dport 1900 -j ACCEPT$/#-A ufw6-before-input -p udp -d ff02::f --dport 1900 -j ACCEPT/' /etc/ufw/before6.rules

	ufw default deny incoming
	ufw default deny outgoing
	ufw default deny routed    # routed can be left as denied so long as it's enabled in the kernel /etc/sysctl.d/[file].conf
	ufw disable
	ufw enable

	# Egress only required traffic
	ufw allow out on "${SERVER_PUB_NIC}" to "${GTWY}" comment 'gateway'
	ufw deny out on "${SERVER_PUB_NIC}" to 127.0.0.0/8 comment 'RFC1918'
	ufw deny out to 10.0.0.0/8 comment 'RFC1918'
	#ufw deny out to 169.254.0.0/16
	ufw deny out to 172.16.0.0/12 comment 'RFC1918'
	ufw deny out to 192.168.0.0/16 comment 'RFC1918'
	# Check for ipv6
	if (grep -qx 'IPV6=yes' /etc/default/ufw); then
		ufw deny out on "${SERVER_PUB_NIC}" to ::1
		ufw deny out to fc00::/7
	fi
	ufw allow out on "${SERVER_PUB_NIC}" to any proto tcp port 80,443,853
	ufw allow out on "${SERVER_PUB_NIC}" to any proto udp port 123 comment 'ntp'
	# Check for unbound running
	systemctl is-active --quiet "unbound"
	UNBOUND_RUNNING=$?
	if [[ ${UNBOUND_RUNNING} -ne 0 ]]; then
		ufw allow out on "${SERVER_PUB_NIC}" to any proto udp port 53
	fi

	# Ingress only required traffic
	ufw allow in on "${SERVER_PUB_NIC}" to any proto tcp port "${SERVER_SSH_PORT}" comment 'ssh'

	# Wireguard server and client rules

	# PostUp|Down commands use their own bash script for readability / portability
	sed -i "s/^PostUp =.*$/PostUp = "${WG_POSTUP_PATH}"/" "/etc/wireguard/${SERVER_WG_NIC}.conf"
	sed -i "s/^PostDown =.*$/PostDown = "${WG_POSTDOWN_PATH}"/" "/etc/wireguard/${SERVER_WG_NIC}.conf"

	systemctl restart "wg-quick@${SERVER_WG_NIC}"

	# Check if WireGuard is running
	systemctl is-active --quiet "wg-quick@${SERVER_WG_NIC}"
	WG_RUNNING=$?
	if [[ ${WG_RUNNING} -ne 0 ]]; then
		echo "WARNING: WireGuard does not seem to be running. Quitting"
		exit 1
	fi

	# PostUpRules
	#iptables -t nat -A POSTROUTING -o "${SERVER_PUB_NIC}" -j MASQUERADE
	#iptables -I INPUT -i "${SERVER_PUB_NIC}" -p udp --dport "${SERVER_WG_PORT}" -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
	#ip6tables -t nat -A POSTROUTING -o "${SERVER_PUB_NIC}" -j MASQUERADE
	#ip6tables -I INPUT -i "${SERVER_PUB_NIC}" -p udp --dport "${SERVER_WG_PORT}" -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '

	#ufw allow in on "${SERVER_PUB_NIC}" to any proto udp port "${SERVER_WG_PORT}" comment 'wg'
	#ufw allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET4}" to "${SERVER_WG_IPV4}" comment 'wg dns'
	#ufw allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET6}" to "${SERVER_WG_IPV6}" comment 'wg dns'
	#ufw route reject in on "${SERVER_WG_NIC}" out on "${SERVER_WG_NIC}" to "${SERVER_WG_NET4}" comment 'client isolation'
	#ufw route reject in on "${SERVER_WG_NIC}" out on "${SERVER_WG_NIC}" to "${SERVER_WG_NET6}" comment 'client isolation'
	#ufw route allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET4}" out on "${SERVER_PUB_NIC}" to any comment 'wg -> eth'
	#ufw route allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET6}" out on "${SERVER_PUB_NIC}" to any comment 'wg -> eth'
	#ufw route allow in on "${SERVER_PUB_NIC}" out on "${SERVER_WG_NIC}" to "${SERVER_WG_NET4}" comment 'eth -> wg'
	#ufw route allow in on "${SERVER_PUB_NIC}" out on "${SERVER_WG_NIC}" to "${SERVER_WG_NET6}" comment 'eth -> wg'

	# PostDown rules
	#iptables -t nat -D POSTROUTING -o "${SERVER_PUB_NIC}" -j MASQUERADE
	#iptables -D INPUT -i "${SERVER_PUB_NIC}" -p udp --dport "${SERVER_WG_PORT}" -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
	#ip6tables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
	#ip6tables -D INPUT -i "${SERVER_PUB_NIC}" -p udp --dport "${SERVER_WG_PORT}" -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '

	#ufw delete allow in on "${SERVER_PUB_NIC}" to any proto udp port "${SERVER_WG_PORT}" comment 'wg'
	#ufw delete allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET4}" to "${SERVER_WG_IPV4}" comment 'wg dns'
	#ufw delete allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET6}" to "${SERVER_WG_IPV6}" comment 'wg dns'
	#ufw route delete reject in on "${SERVER_WG_NIC}" out on "${SERVER_WG_NIC}" to "${SERVER_WG_NET4}" comment 'client isolation'
	#ufw route delete reject in on "${SERVER_WG_NIC}" out on "${SERVER_WG_NIC}" to "${SERVER_WG_NET6}" comment 'client isolation'
	#ufw route delete allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET4}" out on "${SERVER_PUB_NIC}" to any comment 'wg -> eth'
	#ufw route delete allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET6}" out on "${SERVER_PUB_NIC}" to any comment 'wg -> eth'
	#ufw route delete allow in on "${SERVER_PUB_NIC}" out on "${SERVER_WG_NIC}" to "${SERVER_WG_NET4}" comment 'eth -> wg'
	#ufw route delete allow in on "${SERVER_PUB_NIC}" out on "${SERVER_WG_NIC}" to "${SERVER_WG_NET6}" comment 'eth -> wg'
}
setFirewall
