#!/bin/bash

BLUE="\033[01;34m"
YELLOW="\033[01;33m"
RESET="\033[00m"

echo -e "[${BLUE}>${RESET}]Running rootkit checks..."
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
echo -e "[${BLUE}>${RESET}] Running intrusion detection checks..."
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
