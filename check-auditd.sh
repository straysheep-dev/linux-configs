#!/bin/bash

# This script is meant to make querying auditd logs easier with some granularity.

# Thanks to the following projects for code, ideas, and guidance:
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/wireguard-install
# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
# https://github.com/ComplianceAsCode/content
# https://github.com/Neo23x0/auditd
# https://github.com/bfuzzy1/auditd-attack

RED="\033[01;31m"      # Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings
BLUE="\033[01;34m"     # Success
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

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
	echo ""
	echo "check-auditd.sh; a wrapper to summarize auditd logs."
	echo ""
	echo "Pick a time frame:"
	echo ""
	echo "   1) recent (last 10 minutes)"
	echo "   2) today"
	echo "   3) yesterday"
	echo "   4) this-week"
	echo "   5) week-ago"
	echo "   6) boot (since last boot)"
	echo "   7) this-month"
	echo "   8) Quit"
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

for cmd in $CMD_LIST; do
	if (command -v "$cmd" > /dev/null); then
		echo -e "=================================================="
		echo -e ""
		echo -e "${YELLOW}CMD:  $cmd"
		echo -e "TIME: $START_TIME${RESET}"
		echo -e ""
		sudo ausearch -ts "$START_TIME" -i -c $cmd | grep 'proctitle=' | sed 's/ proctitle=/\nproctitle=/g' | grep 'proctitle=' | sed 's/proctitle=//g' | uniq -c | sort -n -r
	fi
done
