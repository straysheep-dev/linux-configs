#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2024 straysheep-dev

# shellcheck disable=SC2034

# check-iw.sh
# Tracks each interface's state and channel

# Colors and color printing code taken directly from:
# https://github.com/carlospolop/PEASS-ng/blob/master/linPEAS/builder/linpeas_parts/linpeas_base.sh
C=$(printf '\033')
DG="${C}[1;90m" #DarkGray
LM="${C}[1;95m" #LightMagenta
SED_RED="${C}[1;31m&${C}[0m"
SED_GREEN="${C}[1;32m&${C}[0m"
SED_YELLOW="${C}[1;33m&${C}[0m"
SED_RED_YELLOW="${C}[1;31;103m&${C}[0m"
SED_BLUE="${C}[1;34m&${C}[0m"
SED_LIGHT_MAGENTA="${C}[1;95m&${C}[0m"
SED_LIGHT_CYAN="${C}[1;96m&${C}[0m"
SED_BOLD="${C}[01;01m&${C}[0m"
NC="${C}[0m"

WIFACE="$1"

while true
do
	clear
	echo -e "${DG}╔═══════════════════════════════════════════════════════════════════${NC}"
	echo -e "${DG}║ Viewing Wireless Interface Information${NC}"
	echo -e "${DG}║ • This will run conitnuously with the latest interface information${NC}"
	echo -e "${DG}║ • Run with ./check-iw.sh wlanX to list nearby Wi-Fi APs with nmcli${NC}"
	echo -e "${DG}║ • Ctrl+c to quit${NC}"
	echo -e "${DG}╚ Hostname: $(hostname) | ${NC}${LM}$(iw reg get | grep -A 1 '^global$' | grep 'country')${NC}${DG} | $(date +%F) $(date +%T)${NC}"

	iw dev | grep -P "(Interface|addr|type|channel)" | \
	sed 's/Interface/\n[◢]/g' | sed -E 's/^\s+//g' | \
	sed -E 's/^addr/   ➤ MAC /g' | \
	sed -E 's/^type/   ➤ Type/g' | \
	sed -E 's/^channel/   ➤ Channel/g' | \
	sed -E "s/.*mon$/${SED_YELLOW}/g" | \
	sed -E "s/^.+Type monitor/${SED_YELLOW}/g" | \
	sed -E "s/^.+wlan[0-9]+$/${SED_GREEN}/g" | \
	sed -E "s/^.+Channel.+/${SED_LIGHT_CYAN}/g"

	echo ""

	if [[ "$1" != '' ]]; then
		# https://unix.stackexchange.com/questions/356753/bash-always-outputs-to-less-how-can-i-turn-this-off
		# https://manpages.debian.org/bookworm/network-manager/nmcli.1.en.html
		# With `|| exit 1`, the script will exit if the interface can't be used
		PAGER=''
		sudo nmcli device wifi list ifname "$WIFACE" || exit 1
	fi

	sleep 1
done
