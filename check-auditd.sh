#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2024 straysheep-dev

# shellcheck disable=SC2034
# shellcheck disable=SC2221
# shellcheck disable=SC2222
# shellcheck disable=SC2317

# This script is meant to make querying auditd logs easier with some granularity.

# Thanks to the following projects for code, ideas, and guidance:
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/wireguard-install
# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
# https://github.com/ComplianceAsCode/content
# https://github.com/Neo23x0/auditd
# https://github.com/bfuzzy1/auditd-attack
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

CMD_LIST='
wget
curl
sudo
whoami
useradd
groupadd
usermod
groupmod
adduser
addgroup
passwd
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
id
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

FILE_LIST='
/etc/passwd
/etc/shadow
/etc/sudoers
.bashrc
'

function UidSummary() {
	echo -e ""
	echo -e "${ITALIC_BLUE}EVENTS BY UID${NC}"
	echo -e ""
	sudo aureport -if "$IF_PATH" -ts "$TIME_START" -te "$TIME_END" -u | cut -d ' ' -f 4 | sort | grep -P "(\-1|(\d){1,})" | uniq -c | sort -nr
}

function CmdEvents() {
	echo -e ""
	echo -e "${ITALIC_BLUE}COMMAND EVENTS${NC}"
	echo -e ""

	for cmd in $CMD_LIST; do
		TMPLOGS_CMD="/tmp/$cmd.tmplog"
		if (command -v "$cmd" > /dev/null); then
			SORTED_COMMANDS="$(sudo ausearch -if "$IF_PATH" -ts "$TIME_START" -te "$TIME_END" -i -l -c "$cmd" 2>/dev/null | grep -Pv "\bsudo (ausearch|aureport)\s+-(ts|if)\b" |  grep 'proctitle=' | sed 's/ proctitle=/\nproctitle=/g' | grep 'proctitle=' | sed 's/proctitle=//g' | sort | uniq -c | sort -n -r)"
			if [[ "$SORTED_COMMANDS" != '' ]]; then
				echo "$SORTED_COMMANDS" > "$TMPLOGS_CMD"
				echo -e "=================================================="
				echo -e ""
				echo -e "${ITALIC}CMD:${NC}  ${LIGHT_MAGENTA}$cmd${NC}"
				echo -e "${ITALIC}TIME:${NC}  ${YELLOW}$TIME_START → $TIME_END${NC}"
				echo -e ""
				sed -E "s/$cmd/$SED_LIGHT_MAGENTA/" "$TMPLOGS_CMD" | sed -E "s/(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_CYAN}/"
			fi
		fi
		# Clean up tmplog files
		rm -f "$TMPLOGS_CMD"
	done
}

function FileEvents() {
	echo -e ""
	echo -e "${ITALIC_BLUE}FILE EVENTS${NC}"
	echo -e ""

	for file in $FILE_LIST; do
		SORTED_EVENTS="$(sudo ausearch -if "$IF_PATH" -ts "$TIME_START" -te "$TIME_END" -i -l -f "$file" 2>/dev/null | grep -Pv "\bsudo (ausearch|aureport)\s+-(ts|if)\b" | grep 'proctitle=' | sed 's/ proctitle=/\nproctitle=/g' | grep 'proctitle=' | sed 's/proctitle=//g' | sort | uniq -c | sort -n -r)"
		if [[ "$SORTED_EVENTS" != '' ]]; then
			echo -e "=================================================="
			echo -e ""
			echo -e "${ITALIC}FILE:${NC}  ${LIGHT_MAGENTA}$file${NC}"
			echo -e "${ITALIC}TIME:${NC}  ${YELLOW}$TIME_START → $TIME_END${NC}"
			echo -e ""
			echo "$SORTED_EVENTS"
		fi
	done
}

function NetEvents() {
	TMPLOGS_NET='/tmp/net-events.tmplog'
	TMPLOGS_CONN='/tmp/connections.tmplog'

	# https://unix.stackexchange.com/questions/304389/remove-newline-character-just-every-n-lines
	echo -e "=================================================="
	echo -e ""
	echo -e "${ITALIC_BLUE}NETWORK CONNECTIONS${NC}"
	echo -e ""
	NET_CONNECTIONS="$(sudo ausearch -if "$IF_PATH" -ts "$TIME_START" -te "$TIME_END" -i -l -sc connect -sv yes  | grep -Pv "\bsudo (ausearch|aureport)\s+-(ts|if)\b" | grep -P "( proctitle=| saddr=)" | sed 's/ proctitle=/\nproctitle=/g' | sed 's/ saddr=/\nsaddr=/g' | grep -P "(proctitle=|saddr=)" | paste -sd ' \n' - | sort )"
	echo "$NET_CONNECTIONS" > "$TMPLOGS_NET"
	echo ""
	echo -e "${ITALIC}${YELLOW}PORTS BY FREQUENCY${NC}"
	grep -oP "lport=(\w){1,5}" "$TMPLOGS_NET" | sort | uniq -c | sort -n -r
	echo ""
	# Create a CSV file of all connections for easy display with `column -t`
	echo -e "${ITALIC}${YELLOW}ADDRESSES BY FREQUENCY${NC}"
	echo "TOTAL,HOST,SYSCALL,USER" | tee "$TMPLOGS_CONN" >/dev/null
	sudo aureport -if "$IF_PATH" -ts "$TIME_START" -h -i | cut -d ' ' -f 4-6 | grep -Pv "(^\s|^=+|host syscall auid)" | sort | uniq -c | sort -nr | sed -E 's/\s+/,/g' | sed -E 's/^,//g' | tee -a "$TMPLOGS_CONN" >/dev/null
	tr ',' '\t' < "$TMPLOGS_CONN" | column -t | sed -E "s/(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_CYAN}/" | sed 's/^/    /g' | sed -E "s/root$/${SED_RED}/"
	echo ""
	echo -e "${ITALIC}${YELLOW}EXTRACTED URLS${NC}"
	# Try to match all protocols, infinite subdomains, directory paths, and finally special characters (essentially any non-space character) appended, followed by alphanumeric characters
	grep -oP "\b\w+(://|@)((\w+\.)?){1,}\w+\.\w+((/\w+)?){1,}(((\S){1,}\w+)?){1,}" "$TMPLOGS_NET" | sort | uniq -c | sort -n -r
	echo ""
	# Extract binaries from the proctitle= field
	echo -e "${ITALIC}${YELLOW}UNIQUE APPLICATIONS${NC}"
	cut -d ' ' -f 1 "$TMPLOGS_NET" | grep -Po 'proctitle=([\S]*)' | sed 's/proctitle=//g' | sort | uniq -c | sort -nr
	echo ""
	echo -e "${ITALIC}${YELLOW}CONNECTIONS BY FREQUENCY${NC}"
	sed -E "s/laddr=(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_CYAN}/" "$TMPLOGS_NET" | sed -E "s/lport=(\w){1,5}/${SED_GREEN}/" | sed -E "s/proctitle=([^[:space:]]*)/${SED_LIGHT_MAGENTA}/"  | sort | uniq -c | sort -n -r
	echo ""
	echo -e "${ITALIC}${YELLOW}CONNECTIONS BY APPLICATION${NC}"
	sed -E "s/^.*proctitle=/proctitle=/g" "$TMPLOGS_NET" | sed -E "s/laddr=(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_CYAN}/" | sed -E "s/lport=(\w){1,5}/${SED_GREEN}/" | sed -E "s/proctitle=([^[:space:]]*)/${SED_LIGHT_MAGENTA}/"  | sort | uniq -c

	# Cleanup tmplog files
	rm -f "$TMPLOGS_NET"
	rm -f "$TMPLOGS_CONN"
}

# Usage options
function HelpMenu() {
	echo -e ""
	echo -e "${LIGHT_MAGENTA}check-auditd.sh${NC}; a wrapper to summarize ${LIGHT_MAGENTA}auditd${NC} logs."
	echo -e ""
	echo -e "${ITALIC}Color scheme: ${LIGHT_MAGENTA}Commands${NC} | ${YELLOW}Time${NC} | ${LIGHT_CYAN}IP Addresses${NC} | ${GREEN}Ports${NC}"
	echo -e ""
	echo -e "This script can do the following:"
	echo -e ""
	echo -e " * Parse active auditd logs or a take a path to offline logs"
	echo -e " * Prints a summary of UIDs appearing in events"
	echo -e " * Search for command events matching a built in list of living-off-the-land binaries"
	echo -e " * Match any entries of a specific [COMMAND]"
	echo -e " * Show each unique command line string, sorted by frequency"
	echo -e " * Shows log entries related to a [FILE], or a built in list of special files, sorted by frequency"
	echo -e " * Summarizes logged network activity, such as dest port, dest IP, URL patterns, or applications making connections"
	echo -e " * Network activity is also sorted by frequency"
	echo -e ""
	echo -e "An attempt is made to filter out command events using specific 'ausearch' and 'aureport' strings to prevent queries from flooding the results."
	echo -e "${ITALIC}Activity must already be logged by audit rules for this script to parse it out of a log file.${NC}"
	echo -e ""
	echo -e "${LIGHT_MAGENTA}[*]Usage: $0 -ts today [-if FILE] [OPTIONS...]${NC}"
	echo -e ""
	echo -e "MAIN ARGUMENTS"
	echo -e ""
	echo -e "     -ts, --start [start-date|start-time|keyword]"
	echo -e "             The time frame to begin searching in logs. Example date: 01/01/2024. Example time: 18:00:00. You can also use keywords."
	echo -e "             Keywords include: now, recent, this-hour, boot, today, yesterday, this-week, week-ago, this-month, this-year, or checkpoint."
	echo -e "             Currently can only use either a date or a time, not both."
	echo -e ""
	echo -e "     -te, --end [end-date|end-time|keyword]"
	echo -e "             The time frame to end searching in logs. If blank, default is 'now'. Like start-time, you can also use keywords."
	echo -e "             Currently can only use either a date or a time, not both."
	echo -e ""
	echo -e "     -if, --input"
	echo -e "             Path to an offline audit log file."
	echo -e ""
	echo -e "     -h, --help"
	echo -e "             Print this help menu."
	echo -e ""
	echo -e "OPTIONAL ARGUMENTS"
	echo -e "     ${ITALIC}Only one of these arguments will work at a time. If multiple are present, the first one wins.${NC}"
	echo -e ""
	echo -e "     -ae, --all-events"
	echo -e "             Display command, file, and network events."
	echo -e ""
	echo -e "     -ne, --net-events"
	echo -e "             Only display network related information."
	echo -e ""
	echo -e "     -fe, --file-events"
	echo -e "             Only display file related information."
	echo -e ""
	echo -e "     -ce, --cmd-events"
	echo -e "             Only display command related information."
	echo -e ""
	echo -e "     -c, --command"
	echo -e "             Match events that include [COMMAND]."
	echo -e ""
	echo -e "     -f, --file"
	echo -e "             Match events that include [FILE]."
	echo -e ""
	exit 0
}

# Show help if there aren't any arguments
if [[ $# -eq 0 ]]; then
	HelpMenu
	exit 1
fi

# This is the easiest way to do this in bash, but it won't work in other shells
# See getopt-parse under /usr/share/doc/util-linux/examples
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
	case $1 in
		-ts|--start)
			TIME_START="$2"
			shift # past argument
			shift # past value
			;;
		-te|--end)
			TIME_END="$2"
			shift # past argument
			shift # past value
			;;
		-ne|--net-events)
			NET_EVENTS="1"
			shift # past argument
			shift # past value
			;;
		-fe|--file-events)
			FILE_EVENTS="1"
			shift # past argument
			shift # past value
			;;
		-ce|--cmd-events)
			CMD_EVENTS="1"
			shift # past argument
			shift # past value
			;;
		-c|--command)
			CMD_SEARCH_STRING="$2"
			shift # past argument
			shift # past value
			;;
		-f|--file)
			FILE_SEARCH_STRING="$2"
			shift # past argument
			shift # past value
			;;
		-if|--input)
			INPUT_FILE="$2"
			shift # past argument
			shift # past value
			;;
		-ae|--all-events)
			ALL_EVENTS="1"
			shift # past argument
			shift # past value
			;;
		-h|--help)
			HelpMenu
			shift # past argument
			shift # past value
			;;
		-*|--*)
			echo "Unknown option $1"
			exit 1
			;;
		*)
			POSITIONAL_ARGS+=("$1") # save positional arg
			shift # past argument
			;;
	esac
done

# Argument logic
CheckAuditd() {

	# If start time -ts argument is missing, exit
	if [[ "$TIME_START" == '' ]]; then
		echo -e "${RED}[*]Missing argument for start time: -ts, --start. See $0 -h for more options.${NC}"
		echo ""
		exit 1
	fi
	# Set current time if -te argument is ommitted
	if [[ "$TIME_END" == '' ]]; then
		TIME_END='now'
	fi

	# Use an input file if -if has an argument
	if [[ "$INPUT_FILE" != '' ]]; then
		IF_PATH="$INPUT_FILE"
	else
		IF_PATH='/var/log/audit/audit.log'
	fi

	# Always execute the UID summary
	UidSummary

	# Execute functions based on arguments
	if [[ "$ALL_EVENTS" == "1" ]]; then
		CmdEvents
		FileEvents
		NetEvents
	fi
	if [[ "$CMD_EVENTS" == "1" ]]; then
		CmdEvents
	fi
	if [[ "$FILE_EVENTS" == "1" ]]; then
		FileEvents
	fi
	if [[ "$NET_EVENTS" == "1" ]]; then
		NetEvents
	fi

	# Use built in lists unless user specifies a search string
	if [[ "$CMD_SEARCH_STRING" != '' ]]; then
		CMD_LIST="$CMD_SEARCH_STRING"
		CmdEvents
	fi
	if [[ "$FILE_SEARCH_STRING" != '' ]]; then
		FILE_LIST="$FILE_SEARCH_STRING"
		FileEvents
	fi

	# Clean up all tmplog files
	rm -f /tmp/*.tmplog
}

CheckAuditd