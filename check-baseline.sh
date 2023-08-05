#!/bin/bash

# GPL-3.0-or-later

# Review the system's current baseline using local IDS databases.
# Many of these tools have no built in terminal color options, this script is meant to make summarizing and reading them easier.

# shellcheck disable=SC2034
# https://en.wikipedia.org/wiki/ANSI_escape_code
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
	echo -e "${LIGHT_MAGENTA}${ITALIC}${BOLD}check-baseline.sh${NC}; a wrapper to summarize ${LIGHT_MAGENTA}${ITALIC}${BOLD}local IDS${NC} data."
	echo -e ""
	echo -e "${ITALIC}${BOLD}COLOR SCHEME:${NC}"
	echo -e "\t• ${LIGHT_MAGENTA}${BOLD}Date / Time${NC}"
	echo -e "\t• ${YELLOW}Filesystem / Checksum Changes${NC}"
	echo -e "\t• ${GREEN}Network Processes${NC}"
	echo -e "\t• ${RED_MAGENTA}Warnings${NC}"
	echo -e "\t• ${RED_BLUE}/etc Files${NC}"
	echo -e "\t• ${RED_YELLOW}/boot, /root, /dev/shm, /tmp, /var/tmp, Hidden (dot) Files${NC}"
	echo -e "\t• ${RED}root User${NC}"
	echo -e ""

}

CheckBaseline() {
	echo -e "[${BLUE}>${NC}] ${BOLD}${UNDERLINED}Running rootkit checks...${NC}"
	echo -e ""
	if (command -v chkrootkit > /dev/null); then
		echo -e "[${YELLOW}i${NC}] ${BOLD}${ITALIC}chkrootkit summary${NC}"
		echo -e ""
		sudo chkrootkit -q | \
		sed -E "s/^\! RUID.+$/${SED_BOLD}/" | \
		sed -E "s/root/${SED_RED}/g" | \
		sed -E "s/\/(dev\/shm|tmp\/|proc\/)/${SED_RED_YELLOW}/" | \
		sed -E "s/\/\.([[:alnum:]]|[[:punct:]])+/${SED_RED_YELLOW}/g" | \
		sed -E "s/^.+(W|w)arning.+$/${SED_RED_MAGENTA}/g" | \
		sed -E "s/^[[:alnum:]]+\: .+$/${SED_GREEN}/g"
		echo -e ""
		echo -e "======================================================================"
		echo -e ""
	fi
	if (command -v rkhunter > /dev/null); then
		echo -e "[${YELLOW}i${NC}] ${BOLD}${ITALIC}rkhunter summary${NC}"
		echo -e ""
		sudo rkhunter --sk --check --rwo | \
		sed -E "s/File: .+$/${SED_YELLOW}/g" | \
		sed -E "s/Warning:.+$/${SED_RED_MAGENTA}/g" | \
		sed -E "s/\/\.([[:alnum:]]|[[:punct:]])+/${SED_RED_YELLOW}/g" | \
		sed -E "s/\(([[:alnum:]]){2}\-([[:alnum:]]){3}\-([[:alnum:]]){4} (([[:alnum:]]){2}:){2}([[:alnum:]]){2}\)/${SED_LIGHT_MAGENTA}/g"
		echo -e ""
		sudo sha256sum /var/lib/rkhunter/db/*\.*
	fi
	echo -e ""
	echo -e "[${BLUE}✓${NC}]rootkit checks complete."
	echo -e ""
	echo -e "======================================================================"
	echo -e ""
	echo -e "[${BLUE}>${NC}] ${BOLD}${UNDERLINED}Running intrusion detection checks...${NC}"
	echo -e ""
	if (command -v aide > /dev/null); then
		if [ -f /etc/aide.conf ]; then
			# fedora
			AIDE_CONF='/etc/aide.conf'
		elif [ -f /etc/aide/aide.conf ]; then
			# debian / ubuntu
			AIDE_CONF='/etc/aide/aide.conf'
		fi
		echo -e "[${YELLOW}i${NC}] ${BOLD}${ITALIC}aide summary${NC}"
		echo -e ""
		# The C or H indicates a change in the file's hash, depending on the version of AIDE.
		sudo aide -c "$AIDE_CONF" -C | \
		sed -E "s/^f...........(C|H).+$/${SED_YELLOW}/g" | \
		sed -E "s/\/(boot|root|dev\/shm|tmp|var\/tmp)\/.+$/${SED_RED_YELLOW}/g" | \
		sed -E "s/\/\.([[:alnum:]]|[[:punct:]])[^\/]+$/${SED_RED_YELLOW}/g" | \
		sed -E "s/\/etc\/.+$/${SED_RED_BLUE}/g"
		echo -e ""
		echo -e ""
		echo -e "======================================================================"
		echo -e ""
	fi
	echo -e ""
	echo -e "[${BLUE}✓${NC}]Done."
}

LOG_NAME=baseline_"$(date +%F_%T)".log

PrintBanner
CheckBaseline | tee ~/"$LOG_NAME"

echo -e "[${BLUE}>${NC}]Log written to ~/$LOG_NAME"
