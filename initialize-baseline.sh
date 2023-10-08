#!/bin/bash

# MIT License
# Copyright (c) 2023, straysheep-dev

# Initializes IDS tools for a system baseline
# Currently only uses aide + rkhunter + chkrootkit
# To do: samhain, tripwire

# Thanks to the following projects for code, ideas, and guidance:
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/wireguard-install

# shellcheck disable=SC2086
# shellcheck disable=SC2034

RED="\033[01;31m"      # Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings
BLUE="\033[01;34m"     # Success
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

# Change these to be your preferred set of tools
IDS_TOOLS='aide
rkhunter
chkrootkit'

# Install IDS tools
echo -e "[${BLUE}>${RESET}]${BOLD}Installing IDS tools...${RESET}"
sudo apt install -y $IDS_TOOLS # Don't quote this

# Prevent cron from automatically changing and updating the databases
echo -e "[${BLUE}>${RESET}]${BOLD}Disabling cron tasks for:
$IDS_TOOLS${RESET}"
for crontask in $IDS_TOOLS; do
	find /etc/cron* -name "$crontask" -print0 | xargs -0 sudo chmod -x
done

function InitializeRkhunter() {
	# rkhunter
	echo -e "[${BLUE}>${RESET}]${BOLD}Configuring rkhunter...${RESET}"
	if [ -e ./rkhunter.conf ]; then
		# Backup default conf
		sudo cp /etc/rkhunter.conf /etc/rkhunter.conf.bkup
		# Install new conf
		sudo cp ./rkhunter.conf /etc
	fi

	# Check config, update database
	sudo rkhunter -C
	sudo rkhunter --propupd
}
function InitializeAide() {
	# Look for a conf filename matching the installed version of aide in the current directory
	echo -e "[${BLUE}>${RESET}]${BOLD}Configuring aide...${RESET}"
	AIDE_VERSION="$(aide -v 2>&1 | grep -oP "\d+\.\d+\.\d+")"
	if [ -e ./aide-"$AIDE_VERSION".conf ]; then
		# Backup default conf
		sudo cp /etc/aide/aide.conf /etc/aide/aide.conf.bkup
		# Install new conf
		for conf in ./aide-"$AIDE_VERSION".conf; do
			sudo cp "$conf" /etc/aide/
		done
	fi

	# Initialize aide, initializing an IDS database should be the last thing you do
	if [ -e /etc/aide/aide.conf ]; then
		sudo aide --init -c /etc/aide/aide.conf
		sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
	else
		echo -e "[${YELLOW}i${RESET}]${BOLD}No configuration file for aide. Quitting.${RESET}"
		exit 1
	fi

}
InitializeRkhunter
InitializeAide
