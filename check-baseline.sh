#!/bin/bash

# GPL-3.0-or-later

# Review the system's current baseline using local IDS databases.
# Many of these tools have no built in terminal color options, this script is meant to make summarizing and reading them easier.

# shellcheck disable=SC2034
# shellcheck disable=SC2221
# shellcheck disable=SC2222
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

function RunRootkitChecks () {
	if (command -v chkrootkit > /dev/null); then
		echo -e "${ITALIC_BLUE}CHKROOTKIT SUMMARY${NC}"
		echo -e ""
		sudo chkrootkit -q | \
		sed -E "s/^\! RUID.+$/${SED_BOLD}/" | \
		sed -E "s/root/${SED_RED}/g" | \
		sed -E "s/\/(dev\/shm|tmp\/|proc\/)/${SED_RED_YELLOW}/" | \
		sed -E "s/\/\.([[:alnum:]]|[[:punct:]])+/${SED_RED_YELLOW}/g" | \
		sed -E "s/^.+(W|w)arning.+$/${SED_WHITE_RED}/g" | \
		sed -E "s/^[[:alnum:]]+\: .+$/${SED_LIGHT_GREEN}/g"
		echo -e ""
		echo -e "======================================================================"
		echo -e ""
	fi
	if (command -v rkhunter > /dev/null); then
		echo -e "${ITALIC_BLUE}RKHUNTER SUMMARY${NC}"
		echo -e ""
		sudo rkhunter --sk --check --rwo | \
		sed -E "s/File: .+$/${SED_YELLOW}/g" | \
		sed -E "s/Warning:.+$/${SED_WHITE_RED}/g" | \
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
}

function RunIDSChecks () {
	if (command -v aide > /dev/null); then
		if [ -f /etc/aide.conf ]; then
			# fedora
			AIDE_CONF='/etc/aide.conf'
		elif [ -f /etc/aide/aide.conf ]; then
			# debian / ubuntu
			AIDE_CONF='/etc/aide/aide.conf'
		fi
		echo -e "${ITALIC_BLUE}AIDE SUMMARY${NC}"
		echo -e ""
		# The C or H indicates a change in the file's hash, depending on the version of AIDE.
		sudo aide -c "$AIDE_CONF" -C | \
		sed -E "s/^f...........(C|H).+$/${SED_YELLOW}/g" | \
		sed -E "s/\/(boot|root|dev\/shm|tmp|var\/tmp)\/.+$/${SED_RED_YELLOW}/g" | \
		sed -E "s/\/\.([[:alnum:]]|[[:punct:]])[^\/]+$/${SED_RED_YELLOW}/g" | \
		sed -E "s/\/etc\/.+$/${SED_LIGHT_CYAN}/g"
		echo -e ""
		echo -e ""
		echo -e "======================================================================"
		echo -e ""
	fi
	echo -e ""
	echo -e "[${BLUE}✓${NC}]Done."
}

function HelpMenu () {
	echo -e ""
	echo -e "${LIGHT_MAGENTA}${ITALIC}${BOLD}check-baseline.sh${NC}; a wrapper to summarize ${LIGHT_MAGENTA}${ITALIC}${BOLD}local IDS${NC} data."
	echo -e ""
	echo -e "${ITALIC}Color scheme:${NC}"
	echo -e " * ${LIGHT_MAGENTA}${BOLD}Date/Time${NC}"
	echo -e " * ${YELLOW}Filesystem/Checksum Changes${NC}"
	echo -e " * ${LIGHT_GREEN}Network Processes${NC}"
	echo -e " * ${WHITE_RED}Warnings${NC}"
	echo -e " * ${LIGHT_CYAN}/etc Files${NC}"
	echo -e " * ${RED}root${NC}"
	echo -e " * ${RED_YELLOW}/boot${NC}, ${RED_YELLOW}/root${NC}, ${RED_YELLOW}/dev/shm${NC}, ${RED_YELLOW}/tmp${NC}, ${RED_YELLOW}/var/tmp${NC}, ${RED_YELLOW}Hidden (dot) Files${NC}"
	echo -e ""
	echo -e "${LIGHT_MAGENTA}[*]Usage: $0 --ids --rootkits${NC}"
	echo -e ""
	echo -e "     -i, --ids"
	echo -e "             Run all IDS checks (aide)."
	echo -e ""
	echo -e "     -r, --rootkits"
	echo -e "             Run all rootkit checks (chkrootkit, rkhunter)"
	echo -e ""
	echo -e "     -a, --all"
	echo -e "             Run all checks."
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
		-r|--rootkits)
			CHECK_ROOTKITS="1"
			shift # past argument
			shift # past value
			;;
		-i|--ids)
			CHECK_IDS="1"
			shift # past argument
			shift # past value
			;;
		-a|--all)
			CHECK_ALL="1"
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
CheckBaseline() {
	# Run all checks
	if [[ "$CHECK_ALL" == '1' ]]; then
		RunRootkitChecks
		RunIDSChecks
	else
		# Only run checks specified as arguments
		if [[ "$CHECK_ROOTKITS" == '1' ]]; then
			RunRootkitChecks
		fi
		if [[ "$CHECK_IDS" == '1' ]]; then
			RunIDSChecks
		fi
	fi
}

LOG_NAME=baseline_"$(date +%Y%m%d_%H%M%S)".log

CheckBaseline | tee ~/"$LOG_NAME"

echo -e "[${BLUE}>${NC}]Log written to ~/$LOG_NAME"