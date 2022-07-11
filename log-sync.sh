#!/bin/bash

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

# Currently meant to work together with pcap-service.sh to gather remote logs from /opt/pcaps
# and copy them to a central logging or analysis system.

ANALYSIS_DIR="$(find ~/ -type d -name "analysis")"

# Try to only match on:
# user@host
# -p port user@host
if (echo "${1}" | grep -Pq "(-p\s(\d){1,5}\s)?\w+@\w+"); then

	if ! [ -d "$ANALYSIS_DIR" ]; then
		echo -e "[${BLUE}>${RESET}]Creating ~/analysis..."
		mkdir -m 770 -p ~/analysis/pcaps || exit
	fi

	# if ANALYSIS_DIR was just created this variable needs the new value
	ANALYSIS_DIR="$(find ~/ -type d -name "analysis")"
	mkdir -m 770 "$ANALYSIS_DIR"/pcaps 2>/dev/null

	echo -e "[${BLUE}>${RESET}]Archiving remote pcaps to local machine..."
	echo -e "[${YELLOW}i${RESET}]action may require interaction with yubikey..."

	# ssh -p <port> <user>@<host> "COMMAND TO RUN ON SERVER" > "REDIRECTED OUTPUT ON LOCAL MACHINE"
	# if the ${1} is double "" quoted, the '-' in '-p' will need \ escaped
	ssh ${1} "cd /opt/pcaps && tar -czf - *.pcap" > "$ANALYSIS_DIR"/"$(date +%Y%m%d)"-pcaps.tar.gz && \

	echo -e "[${BLUE}>${RESET}]Extracting $(date +%Y%m%d)-pcaps.tar.gz into $ANALYSIS_DIR/pcaps/..."
	cd "$ANALYSIS_DIR" || exit
	tar -C "$ANALYSIS_DIR"/pcaps -xzf ./"$(date +%Y%m%d)"-pcaps.tar.gz
	cd "$ANALYSIS_DIR"/pcaps || exit
	mergecap -w "$(date +%Y%m%d)"-merged.pcapng ./*.pcap
	mv "$(date +%Y%m%d)"-merged.pcapng "$ANALYSIS_DIR"
	echo -e "[${GREEN}>${RESET}]~/analysis/$(date +%Y%m%d)-merged.pcap created."

	# This will loop through every pcap, creating a directory named after the pcap file, and generating zeek logs in that directory:
	# Do this in case there's a corrupt capture that makes the merged pcap unreadable.
	if [ -e /opt/zeek/bin/zeek ]; then
		mv "$ANALYSIS_DIR"/pcaps "$ANALYSIS_DIR"/zeek
		cp -r "$ANALYSIS_DIR"/zeek "$ANALYSIS_DIR"/pcaps
		for file in "$ANALYSIS_DIR"/zeek/*.pcap; do mkdir "${file%.*}" && cd "${file%.*}" && /opt/zeek/bin/zeek -C -r "$file"; done
		rm "$ANALYSIS_DIR"/zeek/*.pcap
		echo -e "[${GREEN}>${RESET}]Zeek analysis of pcaps complete."
	fi

	echo -e "[${GREEN}✓${RESET}]Done."
elif [ "${1}" == '-l' ] || [ "${1}" == '--local' ]; then

	if ! [ -d "$ANALYSIS_DIR" ]; then
		echo 'Create a folder named "analysis" anywhere in your ~/ directory.'
		echo 'Add files named *pcaps.tar.gz to that folder before running.'
		echo 'Quitting.' && exit 1
	fi

	mkdir -m 770 "$ANALYSIS_DIR"/pcaps 2>/dev/null

	echo -e "[${BLUE}>${RESET}]Extracting *pcaps.tar.gz into $ANALYSIS_DIR/pcaps/..."
	cd "$ANALYSIS_DIR" || exit
	tar -C "$ANALYSIS_DIR"/pcaps -xzf ./*pcaps.tar.gz
	cd "$ANALYSIS_DIR"/pcaps || exit
	mergecap -w "$(date +%Y%m%d)"-merged.pcapng ./*.pcap
	mv "$(date +%Y%m%d)"-merged.pcapng "$ANALYSIS_DIR"
	echo -e "[${GREEN}>${RESET}]$ANALYSIS_DIR/$(date +%Y%m%d)-merged.pcap created."

	# This will loop through every pcap, creating a directory named after the pcap file, and generating zeek logs in that directory:
	# Do this in case there's a corrupt capture that makes the merged pcap unreadable.
	if [ -e /opt/zeek/bin/zeek ]; then
		echo -e "[${BLUE}>${RESET}]Generating zeek logs..."
		mv "$ANALYSIS_DIR"/pcaps "$ANALYSIS_DIR"/zeek
		cp -r "$ANALYSIS_DIR"/zeek "$ANALYSIS_DIR"/pcaps
		for file in "$ANALYSIS_DIR"/zeek/*.pcap; do mkdir "${file%.*}" && cd "${file%.*}" && /opt/zeek/bin/zeek -C -r "$file"; done
		rm "$ANALYSIS_DIR"/zeek/*.pcap
		echo -e "[${GREEN}>${RESET}]Zeek analysis of pcaps complete."
        fi
else
	echo -e "${BOLD}Usage${RESET}:"
	echo -e "    log-sync '<your-ssh-connect-args>'"
	echo -e "    log-sync [-l|--local]"
	echo ""
	echo -e "${BOLD}Example${RESET}:"
	echo -e "    log-sync '-p 20222 user@localhost'"
	echo -e "    log-sync --local"
	echo ""
	echo -e "[${YELLOW}i${RESET}]wrap the ssh command in quotes ''"
fi

