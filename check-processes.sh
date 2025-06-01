#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2024 straysheep-dev

# shellcheck disable=SC2034

# This script is meant to make reviewing system processes quicker and easier.

# Thanks to the following projects for code, ideas, and guidance:
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/wireguard-install
# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
# https://github.com/ComplianceAsCode/content
# https://github.com/Neo23x0/auditd
# https://github.com/bfuzzy1/auditd-attack
# https://github.com/carlospolop/PEASS-ng

# Regular expressions are used from bstrings by Eric Zimmerman:
# https://github.com/EricZimmerman/bstrings/blob/master/LICENSE.md

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

# List commands as you would in a sed 's/$cmd//' expression
CMD_LIST='(wget|curl|sudo|whoami|pkexec|dbus\-send|gdbus|poweroff|reboot|shutdown|halt|nc|nc\.openbsd|nc\.traditional|ncat|netcat|nmap|tcpdump|ping|ping6|ip|ifconfig|ss|netstat|stunnel|socat|ssh|sftp|ftp|base64|xxd|zip|unzip|gzip|gunzip|tar|bzip2|lzip|lz4|lzop|plzip|pbzip2|pixz|pigz|unpigz|zstd|python|python3|ruby|perl)'

# Write this to a temporary file for parsing
PS_LIST='/tmp/process-list.tmp'

# Banner
echo ""
echo -e "${LIGHT_MAGENTA}check-processes.sh${NC}; a wrapper to visually parse ${LIGHT_MAGENTA}ps auxf${NC}."
echo ""
echo -e "${ITALIC_BLUE}COLOR SCHEME:${NC}"
echo -e "${LIGHT_MAGENTA}Applications${NC}/${RED_YELLOW}Interesting Commands${NC}/${LIGHT_CYAN}URIs${NC}/${GREEN}TTYs${NC}"
echo ""
echo "================================================================================"
echo ""

# Get processes
ps auxf > "$PS_LIST"

# Parse processes with colors
# Matching all combinations of possible full URIs in sed is difficult, only partial matching for now, use together with the summary lines printed by grep below
# IPv4/6 addresses
sed -E "s/(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_CYAN}/" "$PS_LIST" | \
# Protocol connections
#sed -E "s/\w+(:\/\/|@)\w+/${SED_LIGHT_CYAN}/" | \
# SMB connections
sed -E "s/(\\\\\\\\|\/\/)(\w|\S)+/${SED_LIGHT_CYAN}/" | \
# URI and WebDAV port syntax
#sed -E "s/\.\w+(:|@)([[:digit:]]){1,5}/${SED_LIGHT_CYAN}/" | \
# Terminal sessions
sed -E "s/((pts\/|tty)[[:digit:]]+)/${SED_GREEN}/"| \
# Application paths
sed -E "s/\/(\w+[-_]?){1,}\w+(\s|$)/${SED_LIGHT_MAGENTA}/" | \
# Root processes
sed -E "s/^root/${SED_RED}/"| \
# Interesting commands
sed -E "s/\b$CMD_LIST\b/${SED_RED_YELLOW}/"

# Summarize process information
echo "================================================================================"
echo ""
echo -e "${ITALIC}${YELLOW}CPU (%)${NC}"
top -b -n 1 | head -n 3
echo ""
echo -e "${ITALIC}${YELLOW}RAM (GB)${NC}"
free -h
# Parsing UIDS should come before adding lsof network files to the $PS_LIST file, else it parses applications listed by lsof as users
echo ""
echo -e "${ITALIC}${YELLOW}UIDS IN USE${NC}"
cut -d ' ' -f 1 "$PS_LIST" | sort | uniq -c | sort -nr
#echo ""
#echo -e "${ITALIC}${YELLOW}RUNNING JOBS${NC}"
#jobs -l | sort
# https://github.com/strandjs/IntroLabs/blob/master/IntroClassFiles/Tools/IntroClass/LinuxCLI/LinuxCLI.md
echo ""
echo -e "${ITALIC}${YELLOW}NETWORK PROCESS FILES${NC}"
lsof -i -n -P | tee -a "$PS_LIST"
echo ""
echo -e "${ITALIC}${YELLOW}ADDRESSES BY FREQUENCY${NC}"
grep -oP "(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})" "$PS_LIST" | sort | uniq -c | sort -nr
echo ""
echo -e "${ITALIC}${YELLOW}EXTRACTED URIS${NC}"
# Matches by <protocol><ip|uri><path>
# Try to match all protocols, domains + ip addresses, infinite subdomains, directory paths, and finally special characters (essentially any non-space character) appended, followed by alphanumeric characters
# Line below matches all :// URIs and SSH user@host occurances
grep -oP "\w+(://|@)((((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})|(([\w\S]+\.)?){1,}[\w\S]+\.[\w\S]+)(:(\d){1,5})?(((\\\\|/)[\w\S]+)?){1,}(((\S){1,}\[\w\S]+)?){1,}" "$PS_LIST" | sort | uniq -c | sort -nr
# Line below matches all UNC / SMB syntax such as \\\\127.0.0.1 and //localhost.local
grep -oP "(\\\\\\\\|//)((((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})|(([\w\S]+\.)?){1,}[\w\S]+\.[\w\S]+)(@(\d){1,5})?(((\\\\|/)[\w\S]+)?){1,}(((\S){1,}\[\w\S]+)?){1,}" "$PS_LIST" | sort | uniq -c | sort -nr
echo ""
echo -e "${ITALIC}${YELLOW}UNIQUE APPLICATIONS${NC}"
grep -oP "\/(\w+[-_]?){1,}\w+(\s|$)" "$PS_LIST" | sort | uniq -c | sort -nr

# Cleanup
rm "$PS_LIST"

exit
