#!/bin/bash

# shellcheck disable=SC2034

# Vars
PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
GTWY="$(ip route | grep default | cut -d " " -f3)"

# Suggested Values
# See the following webcast for a detailed overview on delpoying ipv6:
# https://www.blackhillsinfosec.com/webcast-ipv6-how-to-securely-start-deploying/
#
# Ingress:
#    Deny All
#    Block Bogons
#    Drop all abnormal packet extension headers at the perimeter
#    Always DROP ICMP type 137 (redirect)
#    Always DROP multicast unless participating in global multicast
#    Do not allow endpoints to advertise ICMPv6 routes
#    Neighbor discovery should not transit the perimeter
#    Allow Type 1: Destination Unreachable, Code 4 (port unreachable)
#    Allow Type 2: Packet too large (else breaks MTU discovery)
#    Allow Type 3: Code 0 only (TTL / Hop expired)
#    Allow Type 4: Code 0 & 1 only, related to header errors
# Optionally:
#    Allow Type 128/129: echo request/reply (based on local ICMP security policy)
#    Allow Types 144-147 ONLY if "mobility enabled"
#    Allow Types 151-153 ONLY if participating in global multicast
#
# Egress:
#    Deny all
#    Allow Types 133/134: Router solicitation/advertisement
#    Allow Types 135/136: Neighbor solicitation/advertisement
#    Allow Types 141/142: Inverse neighbor solicitation/advertisement

ip6tables -F    # Flush all chains
ip6tables -X    # Delete all user-defined chains

## Rules to review and or edit are marked with comments to the right of the rule below

ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT ACCEPT
ip6tables -N ip6-after-forward
ip6tables -N ip6-after-input
ip6tables -N ip6-after-logging-forward
ip6tables -N ip6-after-logging-input
ip6tables -N ip6-after-logging-output
ip6tables -N ip6-after-output
ip6tables -N ip6-before-forward
ip6tables -N ip6-before-input
ip6tables -N ip6-before-logging-forward
ip6tables -N ip6-before-logging-input
ip6tables -N ip6-before-logging-output
ip6tables -N ip6-before-output
ip6tables -N ip6-logging-allow
ip6tables -N ip6-logging-deny
ip6tables -N ip6-reject-forward
ip6tables -N ip6-reject-input
ip6tables -N ip6-reject-output
ip6tables -N ip6-skip-to-policy-forward
ip6tables -N ip6-skip-to-policy-input
ip6tables -N ip6-skip-to-policy-output
ip6tables -N ip6-track-forward
ip6tables -N ip6-track-input
ip6tables -N ip6-track-output
ip6tables -N ip6-user-forward
ip6tables -N ip6-user-input
ip6tables -N ip6-user-limit
ip6tables -N ip6-user-limit-accept
ip6tables -N ip6-user-logging-forward
ip6tables -N ip6-user-logging-input
ip6tables -N ip6-user-logging-output
ip6tables -N ip6-user-output
ip6tables -A INPUT -j ip6-before-logging-input
ip6tables -A INPUT -j ip6-before-input
ip6tables -A INPUT -j ip6-after-input
ip6tables -A INPUT -j ip6-after-logging-input
ip6tables -A INPUT -j ip6-reject-input
ip6tables -A INPUT -j ip6-track-input
ip6tables -A FORWARD -j ip6-before-logging-forward
ip6tables -A FORWARD -j ip6-before-forward
ip6tables -A FORWARD -j ip6-after-forward
ip6tables -A FORWARD -j ip6-after-logging-forward
ip6tables -A FORWARD -j ip6-reject-forward
ip6tables -A FORWARD -j ip6-track-forward
ip6tables -A OUTPUT -j ip6-before-logging-output
ip6tables -A OUTPUT -j ip6-before-output
ip6tables -A OUTPUT -j ip6-after-output
ip6tables -A OUTPUT -j ip6-after-logging-output
ip6tables -A OUTPUT -j ip6-reject-output
ip6tables -A OUTPUT -j ip6-track-output
#ip6tables -A ip6-after-input -p udp -m udp --dport 137 -j ip6-skip-to-policy-input        # Enable manually if using NetBIOS / SMB
#ip6tables -A ip6-after-input -p udp -m udp --dport 138 -j ip6-skip-to-policy-input        # Enable manually if using NetBIOS / SMB
#ip6tables -A ip6-after-input -p tcp -m tcp --dport 139 -j ip6-skip-to-policy-input        # Enable manually if using NetBIOS / SMB
#ip6tables -A ip6-after-input -p tcp -m tcp --dport 445 -j ip6-skip-to-policy-input        # Enable manually if using NetBIOS / SMB
#ip6tables -A ip6-after-input -p udp -m udp --dport 546 -j ip6-skip-to-policy-input
#ip6tables -A ip6-after-input -p udp -m udp --dport 547 -j ip6-skip-to-policy-input
ip6tables -A ip6-after-logging-forward -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IP6TABLES BLOCK] "
ip6tables -A ip6-after-logging-input -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IP6TABLES BLOCK] "
ip6tables -A ip6-after-logging-output -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IP6TABLES BLOCK] "
ip6tables -A ip6-before-forward -m rt --rt-type 0 -j DROP
ip6tables -A ip6-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A ip6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 1/4 -j ACCEPT                                # changed to be code 4 only
ip6tables -A ip6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 2 -j ACCEPT
ip6tables -A ip6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 3/0 -j ACCEPT                                # changed to be code 0 only
ip6tables -A ip6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 4/0 -j ACCEPT                                # changed to be code 0 & 1 only
ip6tables -A ip6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 4/1 -j ACCEPT                                # changed to be code 0 & 1 only
ip6tables -A ip6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 128 -j ACCEPT                                # ALLOW echo request
ip6tables -A ip6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 129 -j ACCEPT                                # ALLOW echo reply
ip6tables -A ip6-before-forward -j ip6-user-forward
ip6tables -A ip6-before-input -i lo -j ACCEPT
ip6tables -A ip6-before-input -m rt --rt-type 0 -j DROP
ip6tables -A ip6-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 129 -j ACCEPT                                  # ALLOW echo reply
ip6tables -A ip6-before-input -m conntrack --ctstate INVALID -j ip6-logging-deny
ip6tables -A ip6-before-input -m conntrack --ctstate INVALID -j DROP
ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 1/4 -j ACCEPT                                  # changed to be code 4 only
ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 2 -j ACCEPT
ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 3/0 -j ACCEPT                                  # changed to be code 0 only
ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 4/0 -j ACCEPT                                  # changed to be code 0 & 1 only
ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 4/1 -j ACCEPT                                  # changed to be code 0 & 1 only
ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 128 -j ACCEPT                                  # ALLOW echo request
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 133 -m hl --hl-eq 255 -j ACCEPT                # DROP Router solicitation/advertisement
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 134 -m hl --hl-eq 255 -j ACCEPT                # DROP Router solicitation/advertisement
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 135 -m hl --hl-eq 255 -j ACCEPT                # DROP Neighbor solicitation/advertisement
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 136 -m hl --hl-eq 255 -j ACCEPT                # DROP Neighbor solicitation/advertisement
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 141 -m hl --hl-eq 255 -j ACCEPT                # DROP Inverse neighbor solicitation/advertisement
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 142 -m hl --hl-eq 255 -j ACCEPT                # DROP Inverse neighbor solicitation/advertisement
#ip6tables -A ip6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 130 -j ACCEPT                      # Required? Multicast listener query https://www.iana.org/go/rfc2710
#ip6tables -A ip6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 131 -j ACCEPT                      # Required? Multicast listener report https://www.iana.org/go/rfc2710
#ip6tables -A ip6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 132 -j ACCEPT                      # Required? Multicast listener done https://www.iana.org/go/rfc2710
#ip6tables -A ip6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 143 -j ACCEPT                      # Required? Multicast listener report v2 https://www.iana.org/go/rfc3810
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 148 -m hl --hl-eq 255 -j ACCEPT                  # Required? SEND https://www.rfc-editor.org/rfc/rfc3971.html
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 149 -m hl --hl-eq 255 -j ACCEPT                  # Required? SEND https://www.rfc-editor.org/rfc/rfc3971.html
#ip6tables -A ip6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 151 -m hl --hl-eq 1 -j ACCEPT        # Only if participating in global multicast https://www.iana.org/go/rfc4286
#ip6tables -A ip6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 152 -m hl --hl-eq 1 -j ACCEPT        # Only if participating in global multicast https://www.iana.org/go/rfc4286
#ip6tables -A ip6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 153 -m hl --hl-eq 1 -j ACCEPT        # Only if participating in global multicast https://www.iana.org/go/rfc4286
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 144 -j ACCEPT                                    # Only if "mobility enabled" https://www.iana.org/go/rfc6275
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 145 -j ACCEPT                                    # Only if "mobility enabled" https://www.iana.org/go/rfc6275
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 146 -j ACCEPT                                    # Only if "mobility enabled" https://www.iana.org/go/rfc6275
#ip6tables -A ip6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 147 -j ACCEPT                                    # Only if "mobility enabled" https://www.iana.org/go/rfc6275
ip6tables -A ip6-before-input -s fe80::/10 -d fe80::/10 -p udp -m udp --sport 547 --dport 546 -j ACCEPT
ip6tables -A ip6-before-input -j ip6-user-input
ip6tables -A ip6-before-output -o lo -j ACCEPT
ip6tables -A ip6-before-output -m rt --rt-type 0 -j DROP
ip6tables -A ip6-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 1/4 -j ACCEPT                                    # changed to be code 4 only
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 2 -j ACCEPT
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 3/0 -j ACCEPT                                    # changed to be code 0 only
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 4/0 -j ACCEPT                                    # changed to be code 0 & 1 only
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 4/1 -j ACCEPT                                    # changed to be code 0 & 1 only
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 128 -j ACCEPT                                    # ALLOW echo request
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 129 -j ACCEPT                                    # ALLOW echo reply
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 133 -m hl --hl-eq 255 -j ACCEPT                   # ALLOW Router solicitation/advertisement
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 136 -m hl --hl-eq 255 -j ACCEPT                   # ALLOW Neighbor solicitation/advertisement
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 135 -m hl --hl-eq 255 -j ACCEPT                   # ALLOW Neighbor solicitation/advertisement
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 134 -m hl --hl-eq 255 -j ACCEPT                   # ALLOW Router solicitation/advertisement
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 141 -m hl --hl-eq 255 -j ACCEPT                   # ALLOW Inverse neighbor solicitation/advertisement
ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 142 -m hl --hl-eq 255 -j ACCEPT                   # ALLOW Inverse neighbor solicitation/advertisement
#ip6tables -A ip6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 130 -j ACCEPT                      # Required? Multicast listener query https://www.iana.org/go/rfc2710
#ip6tables -A ip6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 131 -j ACCEPT                      # Required? Multicast listener report https://www.iana.org/go/rfc2710
#ip6tables -A ip6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 132 -j ACCEPT                      # Required? Multicast listener done https://www.iana.org/go/rfc2710
#ip6tables -A ip6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 143 -j ACCEPT                      # Required? Multicast listener report v2 https://www.iana.org/go/rfc3810
#ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 148 -m hl --hl-eq 255 -j ACCEPT                  # Required? SEND https://www.rfc-editor.org/rfc/rfc3971.html
#ip6tables -A ip6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 149 -m hl --hl-eq 255 -j ACCEPT                  # Required? SEND https://www.rfc-editor.org/rfc/rfc3971.html
#ip6tables -A ip6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 151 -m hl --hl-eq 1 -j ACCEPT        # Only if participating in global multicast https://www.iana.org/go/rfc4286
#ip6tables -A ip6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 152 -m hl --hl-eq 1 -j ACCEPT        # Only if participating in global multicast https://www.iana.org/go/rfc4286
#ip6tables -A ip6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 153 -m hl --hl-eq 1 -j ACCEPT        # Only if participating in global multicast https://www.iana.org/go/rfc4286
ip6tables -A ip6-before-output -j ip6-user-output
ip6tables -A ip6-logging-allow -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IP6TABLES ALLOW] "
ip6tables -A ip6-logging-deny -m conntrack --ctstate INVALID -m limit --limit 3/min --limit-burst 10 -j RETURN
ip6tables -A ip6-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[IP6TABLES BLOCK] "
ip6tables -A ip6-skip-to-policy-forward -j DROP
ip6tables -A ip6-skip-to-policy-input -j DROP
ip6tables -A ip6-skip-to-policy-output -j ACCEPT
ip6tables -A ip6-user-limit -m limit --limit 3/min -j LOG --log-prefix "[IP6TABLES LIMIT BLOCK] "
ip6tables -A ip6-user-limit -j REJECT --reject-with icmp6-port-unreachable
ip6tables -A ip6-user-limit-accept -j ACCEPT
#ip6tables -A ip6-user-output -d fc00::/7 -j DROP
#ip6tables -A ip6-user-output -d ::1/128 -o "$PUB_NIC" -j DROP
#ip6tables -A ip6-user-output -o "$PUB_NIC" -p tcp -m multiport --dports 80,443 -j ACCEPT
#ip6tables -A ip6-user-output -o "$PUB_NIC" -p udp -m udp --dport 53 -j ACCEPT
#ip6tables -A ip6-user-output -o "$PUB_NIC" -p udp -m udp --dport 123 -j ACCEPT


if (command -v apt > /dev/null); then

	if ! (command -v netfilter-persistent > /dev/null); then
		apt install -y iptables-persistent netfilter-persistent
	fi
	if (systemctl is-enabled ufw > /dev/null); then
		systemctl mask ufw.service
	fi
	if (systemctl is-active ufw > /dev/null); then
		systemctl stop ufw.service
	fi
	if ! (systemctl is-enabled netfilter-persistent.service > /dev/null); then
		systemctl enable netfilter-persistent.service
	fi
	if ! (systemctl is-enabled ip6tables.service > /dev/null); then
		systemctl enable ip6tables.service
	fi
	if ! (systemctl is-active netfilter-persistent.service > /dev/null); then
		systemctl start netfilter-persistent.service
	fi
	if ! (systemctl is-active ip6tables.service > /dev/null); then
		systemctl start ip6tables.service
	fi

	netfilter-persistent save
fi

if (command -v dnf > /dev/null); then

	# https://fedoraproject.org/wiki/Firewalld?rd=FirewallD#Using_static_firewall_rules_with_the_iptables_and_ip6tables_services

	if ! (command -v ip6tables-save > /dev/null); then
		dnf install -y iptables-services
	fi
	if (systemctl is-enabled firewalld.service > /dev/null); then
		systemctl mask firewalld.service
	fi
	if (systemctl is-active firewalld.service > /dev/null); then
		systemctl stop firewalld.service
	fi
	if ! (systemctl is-enabled ip6tables.service > /dev/null); then
		systemctl enable ip6tables.service
	fi
	if ! ( systemctl is-active ip6tables.service > /dev/null); then
		systemctl start ip6tables.service
	fi

	cp /etc/sysconfig/ip6tables /etc/sysconfig/ip6tables.bkup

	# Configuration file is saved to:
	ip6tables-save -f /etc/sysconfig/ip6tables
fi
