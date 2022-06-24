#!/bin/bash

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

# Currently meant to work together with pcap-service.sh to gather remote logs from /opt/pcaps
# and copy them to a central logging or analysis system.

# Try to only match on:
# user@host
# -p port user@host
if (echo "${1}" | grep -Pq "(-p\s(\d){1,5}\s)?\w+@\w+"); then
	echo -e "[${BLUE}>${RESET}]Creating ~/analysis..."
	mkdir -m 770 ~/analysis 2>/dev/null
	echo -e "[${BLUE}>${RESET}]Archiving remote pcaps to local machine..."
	echo -e "[${YELLOW}i${RESET}]action may require interaction with yubikey..."

	# ssh -p <port> <user>@<host> "COMMAND TO RUN ON SERVER" > "REDIRECTED OUTPUT ON LOCAL MACHINE"
	# if the ${1} is double "" quoted, the '-' in '-p' will need \ escaped
	ssh ${1} "cd /opt/pcaps && tar -czf - *.pcap" > ~/analysis/$(date +\%Y\%m\%d)-pcaps.tar.gz && \

	cd ~/analysis
	echo -e "[${BLUE}>${RESET}]Extracting $(date +\%Y\%m\%d)-pcaps.tar.gz into ~/analysis/..."
	tar -xzf ./$(date +\%Y\%m\%d)-pcaps.tar.gz
	mergecap -w $(date +\%Y\%m\%d)-merged.pcapng ./*.pcap && \
	echo -e "[${GREEN}>${RESET}]~/analysis/$(date +\%Y\%m\%d)-merged.pcap created."

	# This will loop through every pcap, creating a directory named after the pcap file, and generating zeek logs in that directory:
	# Do this in case there's a corrupt capture that makes the merged pcap unreadable.
	if [ -e /opt/zeek/bin/zeek ]; then
		for file in ~/analysis/*.pcap; do mkdir "${file%.*}" && cd "${file%.*}" && /opt/zeek/bin/zeek -C -r "$file"; done
		rm ~/analysis/*.pcap
		echo -e "[${GREEN}>${RESET}]Zeek analysis of pcaps complete."
	fi

	echo -e "[${GREEN}✓${RESET}]Done."
else
	echo -e "${BOLD}Usage${RESET}: log-sync '<your-ssh-connect-args>'"
	echo -e "${BOLD}Example${RESET}: log-sync '-p 20222 user@localhost'"
	echo -e "[${YELLOW}i${RESET}]wrap the ssh command in quotes ''"
fi
