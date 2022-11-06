#!/bin/bash

# Print all successful ssh connections
function GetSSHConnections() {
	echo "=================================================="
	echo "SSH Connections:"
	echo ""
	for log in /var/log/auth.log*; do
		if (sudo file "$log" | grep -P "ASCII text(, with very long lines( \(\d+\))?)?$" > /dev/null); then
			echo "$log:"
			sudo grep -F 'Accepted' "$log" | sed 's/Accepted/\nAccepted/g' | grep 'Accepted' | sort | uniq -c | sort -n -r
		fi
	done
}

GetSSHConnections

# Print all vpn client connection source addresses
# This requires an iptables rule exists with the word 'Connection' in it's log prefix
# For example:
# iptables -I INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_VPN_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
# This is useful to learn patterns about client connections to better detect anomalies
function GetVPNConnections() {
	echo "=================================================="
	echo "VPN Connections:"
	echo ""
	for log in /var/log/kern.log*; do
		if (sudo file "$log" | grep -P "ASCII text(, with very long lines( \(\d+\))?)?$" > /dev/null); then
			echo "$log:"
			sudo grep 'Connection' "$log" | sed 's/SRC=/\nSRC=/g' | grep 'SRC=' | cut -d ' ' -f 1 | sort | uniq -c | sort -n -r
		fi
	done
}

GetVPNConnections
