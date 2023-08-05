#!/bin/bash

# Review the system's current baseline using IDS databases.

BLUE="\033[01;34m"
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
RED="\033[01;31m"
BOLD="\033[01;01m"
RESET="\033[00m"

CheckBaseline() {
	echo -e "[${BLUE}>${RESET}] ${BOLD}Running rootkit checks...${RESET}"
	echo -e ""
	if (command -v chkrootkit > /dev/null); then
		echo -e "${YELLOW}chkrootkit${RESET} summary:"
		echo -e ""
		sudo chkrootkit -q
		echo -e ""
		echo -e "======================================================================"
		echo -e ""
	fi
	if (command -v rkhunter > /dev/null); then
		echo -e "${YELLOW}rkhunter${RESET} summary:"
		echo -e ""
		sudo rkhunter --sk --check --rwo
		echo -e ""
		sudo sha256sum /var/lib/rkhunter/db/*\.*
	fi
	echo -e ""
	echo -e "[${BLUE}✓${RESET}]rootkit checks complete."
	echo -e ""
	echo -e "======================================================================"
	echo -e ""
	echo -e "[${BLUE}>${RESET}] ${BOLD}Running intrusion detection checks...${RESET}"
	echo -e ""
	if (command -v aide > /dev/null); then
		echo -e "${YELLOW}aide${RESET} summary:"
		echo -e ""
		sudo aide -c /etc/aide/aide.conf -C
		echo -e ""
		echo -e ""
		echo -e "======================================================================"
		echo -e ""
	fi
	echo -e ""
	echo -e "[${BLUE}✓${RESET}]Done."
}

LOG_NAME=baseline_"$(date +%F_%T)".log

CheckBaseline | tee ~/"$LOG_NAME"

echo -e "[${BLUE}>${RESET}]Log written to ~/$LOG_NAME"
