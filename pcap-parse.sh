#!/bin/bash

# shellcheck disable=SC2034

# Parse a large number of pcap files into zeek logs for analysis with RITA.
# This loops through every pcap file, creating a directory named after the pcap file, and generating zeek logs in that directory.
# It's done this way rather than merging all pcaps into a single file, in case there's a corrupt pcap that makes the merged file unreadable.

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset


ANALYSIS_DIR=/tmp/analysis
PCAP_COUNT="$(find "$ANALYSIS_DIR"/pcaps -type f | wc -l)"

if ! [ -e "$ANALYSIS_DIR"/pcaps ]; then
	echo -e "[${YELLOW}i${RESET}]Copy all pcap files for analysis into $ANALYSIS_DIR/pcaps for this script to parse."
	exit
fi

if [ -e /opt/zeek/bin/zeek ]; then
	echo -e "[${BLUE}>${RESET}]Generating zeek logs..."
	rm -rf "$ANALYSIS_DIR"/zeek
	cp -r "$ANALYSIS_DIR"/pcaps "$ANALYSIS_DIR"/zeek
	i=0
	# http://stackoverflow.com/questions/23630501/ddg#23634080
	for file in "$ANALYSIS_DIR"/zeek/*.pcap; do i=$((i+1)); echo -n "Analyzing pcap: $i/$PCAP_COUNT" $'\r'; mkdir "${file%.*}" && cd "${file%.*}" && /opt/zeek/bin/zeek -C -r "$file"; done
	rm "$ANALYSIS_DIR"/zeek/*.pcap
	echo -e "[${GREEN}>${RESET}]Zeek analysis of pcaps complete."
fi
