#!/bin/bash

# GPL-3.0-or-later

# This script is meant to make querying auth logs easier.
# It searches both text and gzip compressed logs.
# If you're trying to trace sudo or root account behavior, it's better to parse auth.log manually or use auditd.

# Thanks to the following projects for code, ideas, and guidance:
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/openvpn-install
# https://github.com/carlospolop/PEASS-ng

# Colors and color printing code taken directly from:
# https://github.com/carlospolop/PEASS-ng/blob/master/linPEAS/builder/linpeas_parts/linpeas_base.sh
C=$(printf '\033')
RED="${C}[1;31m"
SED_RED="${C}[1;31m&${C}[0m"
GREEN="${C}[1;32m"
SED_GREEN="${C}[1;32m&${C}[0m"
YELLOW="${C}[1;33m"
SED_YELLOW="${C}[1;33m&${C}[0m"
RED_YELLOW="${C}[1;31;103m"
SED_RED_YELLOW="${C}[1;31;103m&${C}[0m"
BLUE="${C}[1;34m"
SED_BLUE="${C}[1;34m&${C}[0m"
ITALIC_BLUE="${C}[1;34m${C}[3m"
LIGHT_MAGENTA="${C}[1;95m"
SED_LIGHT_MAGENTA="${C}[1;95m&${C}[0m"
LIGHT_CYAN="${C}[1;96m"
SED_LIGHT_CYAN="${C}[1;96m&${C}[0m"
LG="${C}[1;37m" #LightGray
SED_LG="${C}[1;37m&${C}[0m"
DG="${C}[1;90m" #DarkGray
SED_DG="${C}[1;90m&${C}[0m"
NC="${C}[0m"
UNDERLINED="${C}[5m"
ITALIC="${C}[3m"
BOLD="${C}[01;01m"
SED_BOLD="${C}[01;01m&${C}[0m"

function PrintBanner() {

	echo -e ""
	echo -e "${LIGHT_MAGENTA}${ITALIC}${BOLD}check-auth.sh${NC}; a wrapper to summarize ${LIGHT_MAGENTA}${ITALIC}${BOLD}auth${NC} logs."
	echo -e ""
	echo -e "${ITALIC}${BOLD}COLOR SCHEME:${NC}"
	echo -e "\t• ${BLUE}${BOLD}Log paths${NC}"
	echo -e "\t• ${LIGHT_MAGENTA}${BOLD}Account / User Auth${NC}"
	echo -e "\t• ${GREEN}Local Auth Processes${NC}"
	echo -e "\t• ${YELLOW}Escalation Processes${NC}"
	echo -e "\t• ${RED_YELLOW}SSH root & password Logins${NC}"
	echo -e "\t• ${RED}root User${NC}"
	echo -e "\t• ${LIGHT_CYAN}Remote Login Processes / IP Addresses${NC}"
	echo -e ""

}

# Print all opened account sessions
function GetAccountSessions() {
	echo -e "=================================================="
	echo -e "[${YELLOW}i${NC}] ${BOLD}${ITALIC}Account Sessions${NC}"
	echo -e ""
	for log in /var/log/auth.log*; do
		if (sudo file "$log" | grep -P "ASCII text(, with very long lines( \(\d+\))?)?$" > /dev/null); then
			GREP_CMD=grep
		elif (sudo file "$log" | grep -F "gzip compressed data," > /dev/null); then
			GREP_CMD=zgrep
		fi
		echo -e "${BLUE}${BOLD}$log${NC}:"
		# sudo:session and cron:session authentications are noisy, this filters them out
		sudo "$GREP_CMD" -Pv "((sudo|cron):session|sudo)" "$log" | grep -P "(session opened for user|Accepted google_authenticator)" | sort | uniq -c | sed -E "s/user [[:alnum:]]+/${SED_LIGHT_MAGENTA}/" | sed -E "s/(pkexec|su)/${SED_YELLOW}/" | sed -E "s/sshd/${SED_LIGHT_CYAN}/" | sed -E "s/(gdm|systemd|google_authenticator)/${SED_GREEN}/" | sed -E "s/root/${SED_RED}/"
		echo ""
	done
}

# Print all successful ssh connections
function GetSSHConnections() {
	echo -e "=================================================="
	echo -e "[${YELLOW}i${NC}] ${BOLD}${ITALIC}SSH Connections${NC}"
	echo -e ""
	for log in /var/log/auth.log*; do
		if (sudo file "$log" | grep -P "ASCII text(, with very long lines( \(\d+\))?)?$" > /dev/null); then
			GREP_CMD=grep
		elif (sudo file "$log" | grep -F "gzip compressed data," > /dev/null); then
			GREP_CMD=zgrep
		fi
		echo -e "${BLUE}${BOLD}$log${NC}:"
		sudo "$GREP_CMD" -P "Accepted (password|publickey)" "$log" | sed 's/Accepted/\nAccepted/g' | grep 'Accepted' | sed -E 's/port (\w){1,5} //g' | sort | uniq -c | sort -n -r | sed -E "s/publickey/${SED_GREEN}/" | sed -E "s/for [[:alnum:]]+/${SED_LIGHT_MAGENTA}/" | sed -E "s/(root|password)/${SED_RED_YELLOW}/" | sed -E "s/(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4}|\:\:1)/${SED_LIGHT_CYAN}/"
		echo ""
	done
}

# Print all vpn client connection source addresses
# This requires an iptables rule exists with the word 'Connection' in it's log prefix
# For example:
# iptables -I INPUT -i ${SERVER_PUB_NIC} -p udp --dport ${SERVER_VPN_PORT} -m state --state ESTABLISHED -j LOG --log-prefix 'Wireguard Connection: '
# This is useful to learn patterns about client connections to better detect anomalies
function GetVPNConnections() {
	echo -e "=================================================="
	echo -e "[${YELLOW}i${NC}] ${BOLD}${ITALIC}VPN Connections${NC}"
	echo -e ""
	for log in /var/log/kern.log*; do
		if (sudo file "$log" | grep -P "ASCII text(, with very long lines( \(\d+\))?)?$" > /dev/null); then
			GREP_CMD=grep
		elif (sudo file "$log" | grep -F "gzip compressed data," > /dev/null); then
			GREP_CMD=zgrep
		fi
		echo -e "${BLUE}${BOLD}$log${NC}:"
		sudo "$GREP_CMD" 'Connection' "$log" | sed 's/SRC=/\nSRC=/g' | grep 'SRC=' | cut -d ' ' -f 1 | sort | uniq -c | sort -n -r | sed -E "s/(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4}|\:\:1)/${SED_LIGHT_CYAN}/"
		echo ""
	done
}

PrintBanner
GetAccountSessions
GetSSHConnections
GetVPNConnections
