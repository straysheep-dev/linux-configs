#!/bin/bash

# GPL-3.0-or-later

# This script is meant to make searching and reading auditd logs easier.
# Usage:
# sudo ausearch [options] | ./auditd-parser.sh
# sudo ausearch -ts recent --format interpreted -x suspicious.bin | ./auditd-parser.sh

# Unfortunately this doesn't work well while trying to tail -F /var/log/audit/audit.log
# That will need another solution

# shellcheck disable=SC2034

# Thanks to the following sources for code, ideas, and guidance:
# https://github.com/carlospolop/PEASS-ng
# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
# https://github.com/ComplianceAsCode/content
# https://github.com/Neo23x0/auditd
# https://github.com/bfuzzy1/auditd-attack

# https://en.wikipedia.org/wiki/ANSI_escape_code
# Colors and color printing code taken directly from:
# https://github.com/carlospolop/PEASS-ng/blob/master/linPEAS/builder/linpeas_parts/linpeas_base.sh
C=$(printf '\033')
RED="${C}[1;31m"
SED_RED="${C}[1;31m&${C}[0m"
GREEN="${C}[1;32m"
SED_GREEN="${C}[1;32m&${C}[0m"
LIGHT_GREEN="${C}[1;92m"
SED_LIGHT_GREEN="${C}[1;92m&${C}[0m"
YELLOW="${C}[1;33m"
SED_YELLOW="${C}[1;33m&${C}[0m"
RED_YELLOW="${C}[1;31;103m"
RED_BLUE="${C}[1;31;104m"
RED_MAGENTA="${C}[1;31;105m"
SED_RED_YELLOW="${C}[1;31;103m&${C}[0m"
SED_RED_BLUE="${C}[1;31;104m&${C}[0m"
SED_RED_MAGENTA="${C}[1;31;105m&${C}[0m"
BLUE="${C}[1;34m"
SED_BLUE="${C}[1;34m&${C}[0m"
ITALIC_BLUE="${C}[1;34m${C}[3m"
LIGHT_MAGENTA="${C}[1;95m"
SED_LIGHT_MAGENTA="${C}[1;95m&${C}[0m"
LIGHT_CYAN="${C}[1;96m"
SED_LIGHT_CYAN="${C}[1;96m&${C}[0m"
WHITE_RED="${C}[1;97;41m"
SED_WHITE_RED="${C}[1;97;41m&${C}[0m"
LG="${C}[1;37m" #LightGray
SED_LG="${C}[1;37m&${C}[0m"
DG="${C}[1;90m" #DarkGray
SED_DG="${C}[1;90m&${C}[0m"
NC="${C}[0m"
UNDERLINED="${C}[5m"
ITALIC="${C}[3m"
BOLD="${C}[01;01m"
SED_BOLD="${C}[01;01m&${C}[0m"

# This list is easy to add to
CMD_LIST='(wget|curl|sudo|whoami|pkexec|dbus\-send|gdbus|poweroff|reboot|shutdown|halt|nc|nc\.openbsd|nc\.traditional|ncat|netcat|nmap|tcpdump|ping|ping6|ip|ifconfig|ss|netstat|stunnel|socat|ssh|sftp|ftp|base64|xxd|zip|unzip|gzip|gunzip|tar|bzip2|lzip|lz4|lzop|plzip|pbzip2|pixz|pigz|unpigz|zstd|python|python3|ruby|perl)'

function ParseAuditLog() {
	sed -E "s/\b(([[:digit:]]){2}\/){2}([[:digit:]]){4}/${SED_BLUE}/" | \
	sed -E "s/\b(([[:digit:]]){2}\:){2}([[:digit:]]){2}\.([[:digit:]]){3}\:([[:digit:]]){5}/${SED_LIGHT_CYAN}/" | \
	sed -E "s/(((\w){1,3}\.){3}(\w){1,3}|([a-f0-9]{1,4}(:|::)){3,8}[a-f0-9]{1,4})/${SED_LIGHT_MAGENTA}/" | \
	sed -E "s/\btype=[[:alnum:]]+[[:space:]]/${SED_BOLD}/" | \
	sed -E "s/\b(proctitle=.*$)/${SED_GREEN}/" | \
	sed -E "s/\b(key=.*$)/${SED_YELLOW}/" | \
	sed -E "s/\b(syscall=[[:alnum:]]+[[:space:]])/${SED_LIGHT_CYAN}/" | \
	sed -E "s/\bpid=[[:digit:]]+/${SED_LIGHT_MAGENTA}/" | \
	sed -E "s/\bppid=[[:digit:]]+/${SED_LIGHT_MAGENTA}/" | \
	sed -E "s/\buid=(root|adm)/${SED_RED}/" | \
	sed -E "s/\bgid=(root|adm)/${SED_RED}/" | \
	sed -E "s/\beuid=(root|adm)/${SED_RED}/" | \
	sed -E "s/\begid=(root|adm)/${SED_RED}/" | \
	sed -E "s/\bsuid=(root|adm)\b/${SED_RED_YELLOW}/" | \
	sed -E "s/\bfsuid=(root|adm)/${SED_RED}/" | \
	sed -E "s/\bsgid=(root|adm)\b/${SED_RED_YELLOW}/" | \
	sed -E "s/\bfsgid=(root|adm)/${SED_RED}/" | \
	sed -E "s/\bouid=(root|adm)/${SED_RED}/" | \
	sed -E "s/\bogid=(root|adm)/${SED_RED}/" | \
	sed -E "s/\b$CMD_LIST\b/${SED_RED_YELLOW}/"
}
ParseAuditLog
