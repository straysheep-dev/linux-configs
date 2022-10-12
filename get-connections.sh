#!/bin/bash

# Print all vpn client connection source addresses
# This requires an iptables rule exists with the word 'Connection' in it's log prefix
# For example:
# iptables -I INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_VPN_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
# This is useful to learn patterns about client connections to better detect anomalies

sudo grep 'Connection' /var/log/kern.log | sed 's/SRC=/\nSRC=/g' | grep 'SRC=' | cut -d ' ' -f 1 | sort -u
