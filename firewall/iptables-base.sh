#!/bin/bash

# Vars
PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
GTWY="$(ip route | grep default | cut -d " " -f3)"

iptables -F    # Flush all chains
iptables -X    # Delete all user-defined chains

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -N ip-after-forward
iptables -N ip-after-input
iptables -N ip-after-logging-forward
iptables -N ip-after-logging-input
iptables -N ip-after-logging-output
iptables -N ip-after-output
iptables -N ip-before-forward
iptables -N ip-before-input
iptables -N ip-before-logging-forward
iptables -N ip-before-logging-input
iptables -N ip-before-logging-output
iptables -N ip-before-output
iptables -N ip-logging-allow
iptables -N ip-logging-deny
iptables -N ip-not-local
iptables -N ip-reject-forward
iptables -N ip-reject-input
iptables -N ip-reject-output
iptables -N ip-skip-to-policy-forward
iptables -N ip-skip-to-policy-input
iptables -N ip-skip-to-policy-output
iptables -N ip-track-forward
iptables -N ip-track-input
iptables -N ip-track-output
iptables -N ip-user-forward
iptables -N ip-user-input
iptables -N ip-user-limit
iptables -N ip-user-limit-accept
iptables -N ip-user-logging-forward
iptables -N ip-user-logging-input
iptables -N ip-user-logging-output
iptables -N ip-user-output
iptables -A INPUT -j ip-before-logging-input
iptables -A INPUT -j ip-before-input
iptables -A INPUT -j ip-after-input
iptables -A INPUT -j ip-after-logging-input
iptables -A INPUT -j ip-reject-input
iptables -A INPUT -j ip-track-input
iptables -A FORWARD -j ip-before-logging-forward
iptables -A FORWARD -j ip-before-forward
iptables -A FORWARD -j ip-after-forward
iptables -A FORWARD -j ip-after-logging-forward
iptables -A FORWARD -j ip-reject-forward
iptables -A FORWARD -j ip-track-forward
iptables -A OUTPUT -j ip-before-logging-output
iptables -A OUTPUT -j ip-before-output
iptables -A OUTPUT -j ip-after-output
iptables -A OUTPUT -j ip-after-logging-output
iptables -A OUTPUT -j ip-reject-output
iptables -A OUTPUT -j ip-track-output
#iptables -A ip-after-input -p udp -m udp --dport 137 -j ip-skip-to-policy-input        # Enable manually if using NetBIOS / SMB
#iptables -A ip-after-input -p udp -m udp --dport 138 -j ip-skip-to-policy-input        # Enable manually if using NetBIOS / SMB
#iptables -A ip-after-input -p tcp -m tcp --dport 139 -j ip-skip-to-policy-input        # Enable manually if using NetBIOS / SMB
#iptables -A ip-after-input -p tcp -m tcp --dport 445 -j ip-skip-to-policy-input        # Enable manually if using NetBIOS / SMB
#iptables -A ip-after-input -p udp -m udp --dport 67 -j ip-skip-to-policy-input
#iptables -A ip-after-input -p udp -m udp --dport 68 -j ip-skip-to-policy-input
iptables -A ip-after-input -m addrtype --dst-type BROADCAST -j ip-skip-to-policy-input
iptables -A ip-after-logging-forward -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IPTABLES BLOCK] "
iptables -A ip-after-logging-input -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IPTABLES BLOCK] "
iptables -A ip-after-logging-output -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IPTABLES BLOCK] "
iptables -A ip-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A ip-before-forward -p icmp -m icmp --icmp-type 3 -j ACCEPT
iptables -A ip-before-forward -p icmp -m icmp --icmp-type 11 -j ACCEPT
iptables -A ip-before-forward -p icmp -m icmp --icmp-type 12 -j ACCEPT
iptables -A ip-before-forward -p icmp -m icmp --icmp-type 8 -j ACCEPT
iptables -A ip-before-forward -j ip-user-forward
iptables -A ip-before-input -i lo -j ACCEPT
iptables -A ip-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A ip-before-input -m conntrack --ctstate INVALID -j ip-logging-deny
iptables -A ip-before-input -m conntrack --ctstate INVALID -j DROP
iptables -A ip-before-input -p icmp -m icmp --icmp-type 3 -j ACCEPT
iptables -A ip-before-input -p icmp -m icmp --icmp-type 11 -j ACCEPT
iptables -A ip-before-input -p icmp -m icmp --icmp-type 12 -j ACCEPT
iptables -A ip-before-input -p icmp -m icmp --icmp-type 8 -j ACCEPT
iptables -A ip-before-input -p udp -m udp --sport 67 --dport 68 -j ACCEPT
iptables -A ip-before-input -j ip-not-local
iptables -A ip-before-input -j ip-user-input
iptables -A ip-before-output -o lo -j ACCEPT
iptables -A ip-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A ip-before-output -j ip-user-output
iptables -A ip-logging-allow -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IPTABLES ALLOW] "
iptables -A ip-logging-deny -m conntrack --ctstate INVALID -m limit --limit 3/min --limit-burst 10 -j RETURN
iptables -A ip-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IPTABLES BLOCK] "
iptables -A ip-not-local -m addrtype --dst-type LOCAL -j RETURN
iptables -A ip-not-local -m addrtype --dst-type MULTICAST -j RETURN
iptables -A ip-not-local -m addrtype --dst-type BROADCAST -j RETURN
iptables -A ip-not-local -m limit --limit 3/min --limit-burst 10 -j ip-logging-deny
iptables -A ip-not-local -j DROP
iptables -A ip-skip-to-policy-forward -j DROP
iptables -A ip-skip-to-policy-input -j DROP
iptables -A ip-skip-to-policy-output -j DROP
iptables -A ip-user-limit -m limit --limit 3/min -j LOG --log-prefix "[IPTABLES LIMIT BLOCK] "
iptables -A ip-user-limit -j REJECT --reject-with icmp-port-unreachable
iptables -A ip-user-limit-accept -j ACCEPT
iptables -A ip-user-output -d "$GTWY" -o "$PUB_NIC" -j ACCEPT
iptables -A ip-user-output -d 127.0.0.0/8 -o "$PUB_NIC" -j DROP
iptables -A ip-user-output -d 10.0.0.0/8 -j DROP
iptables -A ip-user-output -d 169.254.0.0/16 -j DROP
iptables -A ip-user-output -d 172.16.0.0/12 -j DROP
iptables -A ip-user-output -d 192.168.0.0/16 -j DROP
iptables -A ip-user-output -o "$PUB_NIC" -p tcp -m multiport --dports 80,443 -j ACCEPT
iptables -A ip-user-output -o "$PUB_NIC" -p udp -m udp --dport 53 -j ACCEPT
iptables -A ip-user-output -o "$PUB_NIC" -p udp -m udp --dport 123 -j ACCEPT
