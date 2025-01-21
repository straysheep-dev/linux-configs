#!/bin/bash

# shellcheck disable=SC2034
# shellcheck disable=SC2044
# Review SC2044 on next edit

# MIT License
# Copyright (c) 2023, straysheep-dev

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

function isRoot() {
        if [ "${EUID}" -eq 0 ]; then
                echo "Run this script as a normal user. Quitting."
                exit 1
        fi
}

isRoot

# Sets the policy path to /usr/lib/firefox
function libPath() {
	# Check Firefox version for /usr/lib directory path
	# Temporary solution until more OS's can be tested
	if [[ -d '/usr/lib/firefox' ]]; then
		FF_DIR=/usr/lib/firefox
	elif [[ -d '/usr/lib/firefox-esr' ]]; then
		FF_DIR=/usr/lib/firefox-esr
	elif [[ -d '/usr/lib64/firefox' ]]; then
		FF_DIR=/usr/lib64/firefox
	else
		FF_DIR=''
	fi
}


# Sets the policy path to /etc/firefox[-esr]
function etcPath() {
	# Check for /etc/ directory path
	# /etc/firefox takes priority over /etc/firefox-esr
	if [[ -d '/etc/firefox' ]]; then
		FF_DIR=/etc/firefox
	elif [[ -d '/etc/firefox-esr' ]]; then
		FF_DIR=/etc/firefox-esr
	else
		FF_DIR=''
	fi
}

function RemoveConfigs() {
	# Check for pre-installed policies and preferences in /etc or /usr/lib, and remove them before writing our own
	# We can safely remove any /etc files found, they may have different naming conventions
	etcPath
	if [ -e "$FF_DIR" ]; then
		for file in $(find "$FF_DIR" -type f); do
			echo -e "[${YELLOW}*${RESET}]${YELLOW}Removing $file...${RESET}"
			sudo rm -f "$file"
		done
	fi
	# We cannot safely remove all files discovered in /usr/lib with "find" here like in /etc, only known configuration files
	libPath
	if [ -e "$FF_DIR"/firefox.cfg ]; then
		echo -e "[${YELLOW}*${RESET}]${YELLOW}Removing $FF_DIR/firefox.cfg...${RESET}"
		sudo rm "$FF_DIR"/firefox.cfg
	fi
	if [ -e "$FF_DIR"/defaults/pref/autoconfig.js ]; then
		echo -e "[${YELLOW}*${RESET}]${YELLOW}Removing $FF_DIR/defaults/pref/autoconfig.js...${RESET}"
		sudo rm "$FF_DIR"/defaults/pref/autoconfig.js
	fi
	if [ -e "$FF_DIR"/distribution/policies.json ]; then
		echo -e "[${YELLOW}*${RESET}]${YELLOW}Removing $FF_DIR/distribution/policies.json...${RESET}"
		sudo rm "$FF_DIR"/distribution/policies.json
	fi
}

function CheckPath() {
	# Check to make sure the firefox path requested exists, exit if not.
	if [ "$FF_DIR" == "" ]; then
		echo -e "[${YELLOW}i${RESET}]${YELLOW}No Firefox path found under $CONFIG_DIR. Quitting."
		exit 1
	fi
}

function CopyToPath() {
	# This function works for every file
	# We can account for any configuration path by changing the following variables:
	# source file (we only need this because the filenames in this repo are prepended with "firefox-")
	# destination file
	# firefox directory
	# extra path (must end with a '/', these are paths within the firefox policy directory)
	if ! [ "$EXTRA_PATH" == "" ]; then
		if ! [ -e "$FF_DIR/$EXTRA_PATH" ]; then
			echo -e "[${GREEN}+${RESET}]${BOLD}Creating directory $FF_DIR/$EXTRA_PATH..."
			sudo mkdir -p "$FF_DIR/$EXTRA_PATH"
		fi
	fi
	if [ -e ./"$SRC_FILE" ]; then
		echo -e "[${GREEN}+${RESET}]${BOLD}Installing $SRC_FILE →${RESET} ${GREEN}$FF_DIR/$EXTRA_PATH$DST_FILE...${RESET}"
		sudo cp ./"$SRC_FILE" "$FF_DIR"/"$EXTRA_PATH""$DST_FILE"
	else
		echo -e "[${YELLOW}i${RESET}]${BOLD}Missing $SRC_FILE.${RESET}"
	fi
}

function WriteCfg() {
	SRC_FILE='firefox-firefox.cfg'
	DST_FILE='firefox.cfg'
	EXTRA_PATH='' # Must end with a '/'
	CopyToPath
}

function WriteAutoconfig() {
	SRC_FILE='firefox-autoconfig.js'
	DST_FILE='autoconfig.js'
	EXTRA_PATH='defaults/pref/' # Must end with a '/'
	CopyToPath
}

function WriteSyspref() {
	# Firefox-esr still uses /etc/firefox-esr for syspref.js
	SRC_FILE='firefox-syspref.js'
	DST_FILE='syspref.js'
	EXTRA_PATH=''  # Must end with a '/'
	CopyToPath
}

function WritePolicies() {
	SRC_FILE='firefox-policies.json'
	DST_FILE='policies.json'
	if (grep -q "^ID=kali$" /etc/os-release); then
		SRC_FILE='firefox-policies-kali.json'
	fi
	if [[ $CONFIG_DIR == "etc" ]]; then
		EXTRA_PATH='policies/' # Must end with a '/'
		# This is always the policies.json path for firefox or firefox-esr
		CopyToPath
	elif [[ $CONFIG_DIR == "lib" ]]; then
		EXTRA_PATH='distribution/' # Must end with a '/'
		CopyToPath
	fi
}

# Management Menu
echo -e "${BOLD}Which path will be used for the configuration files?${RESET}"
echo ""
echo -e "[${BLUE}/etc${RESET}] ${BOLD}system-wide, both package manager and snap packages can read these (snap package cannot read the .js files)${RESET}"
echo "   • /etc/firefox/syspref.js"
echo "   • /etc/firefox/policies/"
echo "   • /etc/firefox/policies/policies.json"
echo "   • /etc/firefox/pref/"
echo "   • /etc/firefox/pref/local.js"
echo "   • /etc/firefox/profile"
echo ""
echo -e "[${BLUE}/usr/lib${RESET}] ${BOLD}system-wide, but only for the package installed by the package manager (snap package cannot read these)${RESET}"
echo "   • /usr/lib/firefox/firefox.cfg"
echo "   • /usr/lib/firefox/distribution/policies.json"
echo "   • /usr/lib/firefox/defaults/pref/autoconfig.js"
echo ""
until [[ $CONFIG_DIR =~ ^(etc|lib)$ ]]; do
	read -rp "Configuration directory [etc|lib]: " CONFIG_DIR
done

if [[ $CONFIG_DIR == "etc" ]]; then
	RemoveConfigs
	etcPath
	CheckPath
	echo -e "[${BLUE}*${RESET}]${BOLD}Using${RESET} ${GREEN}$FF_DIR${RESET} ${BOLD}as configuration path...${RESET}"
	WriteSyspref
	WritePolicies
elif [[ $CONFIG_DIR == "lib" ]]; then
	RemoveConfigs
	libPath
	CheckPath
	echo -e "[${BLUE}*${RESET}]${BOLD}Using${RESET} ${GREEN}$FF_DIR${RESET} ${BOLD}as configuration path...${RESET}"
	WriteCfg
	WriteAutoconfig
	WritePolicies
fi

echo -e "[${BLUE}*${RESET}]${BOLD}Done.${RESET}"
