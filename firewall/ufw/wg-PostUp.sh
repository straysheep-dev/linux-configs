#!/bin/bash

# Wireguard PostUp script

# shellcheck disable=SC2034

GTWY="$(ip route | grep 'default' | grep -Po '(?<=via )(\S+)' | head -1)"
WG="$(ip a | grep -o "wg[0-9]" | head -1)"

SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
SERVER_WG_NIC="$(grep SERVER_WG_NIC /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_PORT="$(grep SERVER_PORT /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_IPV4="$(grep SERVER_WG_IPV4 /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_IPV6="$(grep SERVER_WG_IPV6 /etc/wireguard/params | cut -d '=' -f 2)"
SERVER_WG_NET4="$(grep -P "^Address" /etc/wireguard/"${SERVER_WG_NIC}".conf | grep -oP "$SERVER_WG_IPV4/\d\d" | sed 's/\.[[:digit:]]\//\.0\//')"
SERVER_WG_NET6="$(grep -P "^Address" /etc/wireguard/"${SERVER_WG_NIC}".conf | grep -oP "$SERVER_WG_IPV6/\d\d" | sed 's/:[[:digit:]]\//:\//')"
SERVER_SSH_PORT="$(grep -E "^Port ([0-9]{1,5})" /etc/ssh/sshd_config | cut -d ' ' -f 2)"

# PostUpRules
iptables -I FORWARD -i "${SERVER_WG_NIC}" -o "${SERVER_WG_NIC}" -j REJECT --reject-with icmp-admin-prohibited
iptables -t nat -A POSTROUTING -o "${SERVER_PUB_NIC}" -j MASQUERADE
iptables -I INPUT -i "${SERVER_PUB_NIC}" -p udp --dport "${SERVER_WG_PORT}" -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
ip6tables -I FORWARD -i "${SERVER_WG_NIC}" -o "${SERVER_WG_NIC}" -j REJECT --reject-with icmp6-adm-prohibited
ip6tables -t nat -A POSTROUTING -o "${SERVER_PUB_NIC}" -j MASQUERADE
ip6tables -I INPUT -i "${SERVER_PUB_NIC}" -p udp --dport "${SERVER_WG_PORT}" -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '

ufw allow in on "${SERVER_PUB_NIC}" to any proto udp port "${SERVER_WG_PORT}" comment 'wg'
ufw allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET4}" to "${SERVER_WG_IPV4}" comment 'wg dns'
ufw allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET6}" to "${SERVER_WG_IPV6}" comment 'wg dns'
ufw route allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET4}" out on "${SERVER_PUB_NIC}" to any comment 'wg -> eth'
ufw route allow in on "${SERVER_WG_NIC}" from "${SERVER_WG_NET6}" out on "${SERVER_PUB_NIC}" to any comment 'wg -> eth'
