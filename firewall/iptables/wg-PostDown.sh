#!/bin/bash

# Wireguard PostDown script

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

# PostDown rules

iptables -D FORWARD -i "${SERVER_WG_NIC}" -o "${SERVER_WG_NIC}" -j REJECT --reject-with icmp-admin-prohibited
iptables -D FORWARD -i "${SERVER_WG_NIC}" -j ACCEPT
iptables -D INPUT -i "${SERVER_WG_NIC}" -d "${SERVER_WG_IPV4}" -j ACCEPT
iptables -t nat -D POSTROUTING -o "${SERVER_PUB_NIC}" -j MASQUERADE
iptables -D INPUT -i "${SERVER_PUB_NIC}" -p udp --dport "${SERVER_WG_PORT}" -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
ip6tables -D FORWARD -i "${SERVER_WG_NIC}" -o "${SERVER_WG_NIC}" -j REJECT --reject-with icmp6-adm-prohibited
ip6tables -D FORWARD -i "${SERVER_WG_NIC}" -j ACCEPT
ip6tables -D INPUT -i "${SERVER_WG_NIC}" -d "${SERVER_WG_IPV6}" -j ACCEPT
ip6tables -t nat -D POSTROUTING -o "${SERVER_PUB_NIC}" -j MASQUERADE
ip6tables -D INPUT -i "${SERVER_PUB_NIC}" -p udp --dport "${SERVER_WG_PORT}" -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '

