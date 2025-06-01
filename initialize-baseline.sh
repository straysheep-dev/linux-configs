#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2023, straysheep-dev

# shellcheck disable=SC2086
# shellcheck disable=SC2034
# shellcheck disable=SC2144

# Initializes IDS tools for a system baseline
# Currently only uses aide + rkhunter + chkrootkit
# To do: samhain, tripwire

# Thanks to the following projects for code, ideas, and guidance:
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/wireguard-install

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

function InstallIDSTools() {
	echo -e "[${BLUE}>${RESET}]${BOLD}Installing IDS tools...${RESET}"
	sudo apt update

	# The local mail applications break on WSL, use --no-install-recommends to avoid installing them
	# This includes aide-common, the directories for aide must be created manually
	# The directory paths below are for Debian based systems (Ubuntu, Kali) Fedora will have different paths
	if [ -e /etc/wsl.conf ]; then
	        sudo apt install -y --no-install-recommends $IDS_TOOLS # Don't quote this
	        sudo mkdir /etc/aide
	        sudo mkdir /var/lib/aide/
	        sudo mkdir /var/log/aide
	else
		sudo apt install -y $IDS_TOOLS # Don't quote this
	fi

	# Prevent cron from automatically modifying and updating the databases
	# You'll want to write and schedule your own cron task for checking baselines
	# Send the results to a logging server or alert channel
        for crontask in $IDS_TOOLS; do
                echo -e "[${BLUE}>${RESET}]${BOLD}Disabling cron tasks for: $crontask${RESET}"
                find /etc/cron* -name "$crontask" -print0 | xargs -0 sudo chmod -x 2>/dev/null
        done
}

function InitializeRkhunter() {
	# rkhunter
	echo -e "[${BLUE}>${RESET}]${BOLD}Configuring rkhunter...${RESET}"
	if [ -e ./rkhunter.conf ]; then
		# Backup default conf
		sudo cp /etc/rkhunter.conf /etc/rkhunter.conf.bkup
		# Install new conf
		sudo cp ./rkhunter/rkhunter.conf /etc
	fi

	# Check config, update database
	sudo rkhunter -C
	sudo rkhunter --propupd
}

function InitializeAide() {
	# Look for a conf filename matching the installed version of aide in the current directory
	# The conf syntax changed from version 16 to 17, so multiple files may be present
	# Version 16 is the default in Ubuntu 20.04 while 22.04 uses aide version 17
	echo -e "[${BLUE}>${RESET}]${BOLD}Configuring aide...${RESET}"
	AIDE_VERSION="$(aide -v 2>&1 | grep -oP "\d+\.\d+\.")"
	if [ -e ./aide-"$AIDE_VERSION"[0-9].conf ]; then
		# Backup default conf
		sudo cp /etc/aide/aide.conf /etc/aide/aide.conf.bkup

		# Install new conf
		for conf in ./aide/aide-"$AIDE_VERSION"[0-9].conf; do
			sudo cp "$conf" /etc/aide/aide.conf
		done
        else
                echo -e "[${YELLOW}i${RESET}]${BOLD}No configuration file for aide found in current directory. Quitting.${RESET}"
                exit 1
	fi

	# Initialize aide, initializing an IDS database should be the last thing you do
	sudo aide --init -c /etc/aide/aide.conf
	sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
	echo -e "[${YELLOW}i${RESET}] ${BOLD}Save the above values to your password manager${RESET}"
}

InstallIDSTools
InitializeRkhunter
InitializeAide
