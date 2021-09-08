#!/bin/bash

# Modify the wireguard iptables rules
# Client isolation rejecting wg0 <--> wg0 traffic
# Allow client --> wg0 dns
# Logs wireguard client authentications to /var/log/syslog

SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
SERVER_WG_NIC="$(grep SERVER_WG_NIC /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_PORT="$(grep SERVER_PORT /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_IPV4="$(grep SERVER_WG_IPV4 /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_IPV6="$(grep SERVER_WG_IPV6 /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_SSH_PORT="$(grep -E "^Port ([0-9]{1,5})" /etc/ssh/sshd_config | cut -d ' ' -f 2)"

function isRoot() {
        if [ "${EUID}" -ne 0 ]; then
                echo "You need to run this script as root"
                exit 1
        fi
}
isRoot

function setFirewall() {
	ufw reset

	sed -i "s/^PostUp =.*$/PostUp = iptables -I FORWARD -i ${SERVER_WG_NIC} -o ${SERVER_WG_NIC} -j REJECT --reject-with icmp-admin-prohibited; iptables -A FORWARD -i ${SERVER_WG_NIC} -j ACCEPT; iptables -A INPUT -i ${SERVER_WG_NIC} -d ${SERVER_WG_IPV4} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; iptables -I INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_WG_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '; ip6tables -I FORWARD -i ${SERVER_WG_NIC} -o ${SERVER_WG_NIC} -j REJECT --reject-with icmp6-adm-prohibited; ip6tables -A FORWARD -i ${SERVER_WG_NIC} -j ACCEPT; ip6tables -A INPUT -i ${SERVER_WG_NIC} -d ${SERVER_WG_IPV6} -j ACCEPT; ip6tables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; ip6tables -I INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_WG_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '/" "/etc/wireguard/${SERVER_WG_NIC}.conf"
	sed -i "s/^PostDown =.*$/PostDown = iptables -D FORWARD -i ${SERVER_WG_NIC} -o ${SERVER_WG_NIC} -j REJECT --reject-with icmp-admin-prohibited; iptables -D FORWARD -i ${SERVER_WG_NIC} -j ACCEPT; iptables -D INPUT -i ${SERVER_WG_NIC} -d ${SERVER_WG_IPV4} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; iptables -D INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_WG_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '; ip6tables -D FORWARD -i ${SERVER_WG_NIC} -o ${SERVER_WG_NIC} -j REJECT --reject-with icmp6-adm-prohibited; ip6tables -D FORWARD -i ${SERVER_WG_NIC} -j ACCEPT; ip6tables -D INPUT -i ${SERVER_WG_NIC} -d ${SERVER_WG_IPV6} -j ACCEPT; ip6tables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; ip6tables -D INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_WG_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '/" "/etc/wireguard/${SERVER_WG_NIC}.conf"

# To do: alternate PostUp/Down rules using ufw
#	PostUp = ufw route reject in on ${SERVER_WG_NIC} out on ${SERVER_WG_NIC};
#	ufw allow in on ${SERVER_WG_NIC} to ${SERVER_WG_IPV4} comment 'dns';
#	iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE;
#	ip6tables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE;
#	iptables -I INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_WG_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '	
#	ip6tables -I INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_WG_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
#	ufw route allow in on ${SERVER_WG_NIC} out on ${SERVER_PUB_NIC}

#	PostDown = ufw delete route reject in on ${SERVER_WG_NIC} out on ${SERVER_WG_NIC};
#	ufw delete allow in on ${SERVER_WG_NIC} to ${SERVER_WG_IPV4} comment 'dns';
#	iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE;
#	ip6tables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE;
#	iptables -D INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_WG_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '	
#	ip6tables -D INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_WG_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
#	ufw delete route allow in on ${SERVER_WG_NIC} out on ${SERVER_PUB_NIC}

	systemctl restart "wg-quick@${SERVER_WG_NIC}"

	# Check if WireGuard is running
	systemctl is-active --quiet "wg-quick@${SERVER_WG_NIC}"
	WG_RUNNING=$?
	if [[ ${WG_RUNNING} -ne 0 ]]; then
		echo "WARNING: WireGuard does not seem to be running. Quitting"
		exit 1
	fi	

	sed -i 's/^-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT$/#-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT/' /etc/ufw/before.rules
	sed -i 's/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT$/#-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT/' /etc/ufw/before.rules

	sed -i 's/^-A ufw6-before-input -p udp -d ff02::fb --dport 5353 -j ACCEPT$/#-A ufw6-before-input -p udp -d ff02::fb --dport 5353 -j ACCEPT/' /etc/ufw/before6.rules
	sed -i 's/^-A ufw6-before-input -p udp -d ff02::f --dport 1900 -j ACCEPT$/#-A ufw6-before-input -p udp -d ff02::f --dport 1900 -j ACCEPT/' /etc/ufw/before6.rules
	
	ufw default deny incoming
	ufw default deny outgoing
	ufw default deny routed
	ufw disable
	ufw enable
	ufw allow out on "${SERVER_PUB_NIC}" to any proto tcp port 80,443,853
	ufw allow out on "${SERVER_PUB_NIC}" to any proto udp port 123
	# Check for unbound running
	systemctl is-active --quiet "unbound"
	UNBOUND_RUNNING=$?
	if [[ ${UNBOUND_RUNNING} -ne 0 ]]; then
		ufw allow out on "${SERVER_PUB_NIC}" to any proto udp port 53
	fi
	ufw allow in on "${SERVER_PUB_NIC}" to any proto udp port "${SERVER_WG_PORT}" comment 'wg'
	ufw allow in on "${SERVER_PUB_NIC}" to any proto tcp port "${SERVER_SSH_PORT}" comment 'ssh'
	ufw prepend deny out to 192.168.0.0/16
	ufw prepend deny out to 172.16.0.0/12
	ufw prepend deny out to 169.254.0.0/16
	ufw prepend deny out to 10.0.0.0/8
	ufw prepend deny out on "${SERVER_PUB_NIC}" to 127.0.0.0/8
	# Check for ipv6
	if (grep -qx 'IPV6=yes' /etc/default/ufw); then
		ufw prepend deny out to fc00::/7
		ufw prepend deny out on "${SERVER_PUB_NIC}" to ::1
	fi
}
setFirewall
