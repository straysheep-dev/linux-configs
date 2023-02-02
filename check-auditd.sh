#!/bin/bash

# GPL-3.0-or-later

# This script is meant to make querying auditd logs easier with some granularity.

# Thanks to the following projects for code, ideas, and guidance:
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/wireguard-install
# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
# https://github.com/ComplianceAsCode/content
# https://github.com/Neo23x0/auditd
# https://github.com/bfuzzy1/auditd-attack
# https://github.com/carlospolop/PEASS-ng

# shellcheck disable=SC2034
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


# Check if root, exit
function isRoot() {
	if [ "${EUID}" -eq 0 ]; then
		echo "You need to run this script as a normal user"
		exit 1
	fi
}

isRoot

# Options for the time frame of the query
function TimeMenu() {
	echo -e ""
	echo -e "${LIGHT_MAGENTA}check-auditd.sh${NC}; a wrapper to summarize ${LIGHT_MAGENTA}auditd${NC} logs."
	echo -e ""
	echo -e "${ITALIC_BLUE}COLOR SCHEME:${NC}"
	echo -e "${LIGHT_MAGENTA}Commands${NC}/${YELLOW}Time${NC}/${LIGHT_CYAN}IP Addresses${NC}/${GREEN}Ports${NC}"
	echo -e ""
	echo -e "Pick a time frame:"
	echo -e ""
	echo -e "   1) ${YELLOW}recent${NC} (last 10 minutes)"
	echo -e "   2) ${YELLOW}today${NC}"
	echo -e "   3) ${YELLOW}yesterday${NC}"
	echo -e "   4) ${YELLOW}this-week${NC}"
	echo -e "   5) ${YELLOW}week-ago${NC}"
	echo -e "   6) ${YELLOW}boot${NC} (since last boot)"
	echo -e "   7) ${YELLOW}this-month${NC}"
	echo -e "   8) Quit"
	until [[ $MENU_OPTION =~ ^[1-8]$ ]]; do
		read -rp "Select an option [1-8]: " MENU_OPTION
	done

	case $MENU_OPTION in
	1)
		START_TIME='recent'
		;;
	2)
		START_TIME='today'
		;;
	3)
		START_TIME='yesterday'
		;;
	4)
		START_TIME='this-week'
		;;
	5)
		START_TIME='week-ago'
		;;
	6)
		START_TIME='boot'
		;;
	7)
		START_TIME='this-month'
		;;
	8)
		exit 0
		;;
	esac
}

TimeMenu

CMD_LIST='
wget
curl
sudo
whoami
pkexec
dbus-send
gdbus
poweroff
reboot
shutdown
halt
nc
nc.openbsd
nc.traditional
ncat
netcat
nmap
tcpdump
ping
ping6
ip
ifconfig
ss
netstat
stunnel
socat
ssh
sftp
ftp
base64
xxd
zip
unzip
gzip
gunzip
tar
bzip2
lzip
lz4
lzop
plzip
pbzip2
pixz
pigz
unpigz
zstd
python
python3
ruby
perl
'

echo -e ""
echo -e "${ITALIC_BLUE}COMMAND HISTORY${NC}"
echo -e ""

for cmd in $CMD_LIST; do
	if (command -v "$cmd" > /dev/null); then
		echo -e "=================================================="
		echo -e ""
		echo -e "${ITALIC}CMD:${NC}  ${LIGHT_MAGENTA}$cmd${NC}"
		echo -e "${ITALIC}TIME:${NC}  ${YELLOW}$START_TIME${NC}"
		echo -e ""
		SORTED_COMMANDS="$(sudo ausearch -ts "$START_TIME" -i -l -c "$cmd" | grep 'proctitle=' | sed 's/ proctitle=/\nproctitle=/g' | grep 'proctitle=' | sed 's/proctitle=//g' | uniq -c | sort -n -r)"
		echo "$SORTED_COMMANDS" | sed -E "s/$cmd/$SED_LIGHT_MAGENTA/" | sed -E "s/(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_CYAN}/"
	fi
done

# https://unix.stackexchange.com/questions/304389/remove-newline-character-just-every-n-lines
echo -e "=================================================="
echo -e ""
echo -e "${ITALIC_BLUE}NETWORK CONNECTIONS${NC}"
echo -e ""
NET_CONNECTIONS="$(sudo ausearch -ts today -i -l -sc connect -sv yes | grep -P "( proctitle=| saddr=)" | sed 's/ proctitle=/\nproctitle=/g' | sed 's/ saddr=/\nsaddr=/g' | grep -P "(proctitle=|saddr=)" | paste -sd ' \n' - | sort )"
echo "$NET_CONNECTIONS" > /tmp/net-connections.txt
echo ""
echo -e "${ITALIC}${YELLOW}PORTS BY FREQUENCY${NC}"
grep -oP "lport=(\w){1,5}" /tmp/net-connections.txt | sort | uniq -c | sort -n -r
echo ""
echo -e "${ITALIC}${YELLOW}ADDRESSES BY FREQUENCY${NC}"
grep -oP "laddr=(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})" /tmp/net-connections.txt | sort | uniq -c | sort -n -r
echo ""
echo -e "${ITALIC}${YELLOW}EXTRACTED URLS${NC}"
# Try to match all protocols, infinite subdomains, directory paths, and finally special characters (essentially any non-space character) appended, followed by alphanumeric characters
grep -oP "\b\w+(://|@)((\w+\.)?){1,}\w+\.\w+((/\w+)?){1,}(((\S){1,}\w+)?){1,}" /tmp/net-connections.txt | sort | uniq -c | sort -n -r
echo ""
echo -e "${ITALIC}${YELLOW}CONNECTIONS BY FREQUENCY${NC}"
sed -E "s/laddr=(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_CYAN}/" /tmp/net-connections.txt | sed -E "s/lport=(\w){1,5}/${SED_GREEN}/" | sed -E "s/(\/|=)\w+\S?\w+\s/${SED_LIGHT_MAGENTA}/"  | sort | uniq -c | sort -n -r
echo ""
echo -e "${ITALIC}${YELLOW}CONNECTIONS BY APPLICATION${NC}"
sed -E "s/laddr=(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_CYAN}/" /tmp/net-connections.txt | sed -E "s/lport=(\w){1,5}/${SED_GREEN}/" | sed -E "s/(\/|=)\w+\S?\w+\s/${SED_LIGHT_MAGENTA}/"  | sort | uniq -c | sort -k 2
rm /tmp/net-connections.txt
