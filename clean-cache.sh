#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2024 straysheep-dev

# VMware's drag and drop feature can (over time) cache a large number of files consuming disk space.
# On Linux, Ctrl+C copying a file within a guest VM can cause a copy of the file to be cached on the host.
# This requires copy and paste to be enabled for the guest, and can happen even if you're pasting the file within the same guest.
# This script shows the current user's disk usage and optionally deletes any discovered files.
# Other cached or temporary file locations may be added in the future.
# Tested on Ubuntu 22.04

BLUE="\033[01;34m"
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
RESET="\033[00m"

function PrintUsage() {
	echo -e "[${BLUE}i${RESET}]Usage: clean-cache [options]"
	echo -e ""
	echo -e "    -c, --check"
	echo -e "                Check for cached files, show disk usage."
	echo -e "    -d, --delete"
	echo -e "                Delete cached files."
	echo -e "    -v, --verbose"
	echo -e "                List cached files when using -c,--check. Must be the second argument."
}

if [ "$1" == '-c' ] || [ "$1" == '--check' ]; then

	echo -e "[${BLUE}>${RESET}]Checking ${GREEN}trash${RESET}..."
	echo -e "Cache size: $(du -h -d0 ~/.local/share/Trash/)"
	echo ''

	if [ -e ~/.cache/thumbnails/large ]; then
		echo -e "[${BLUE}>${RESET}]Checking for cached ${GREEN}thumbnails${RESET}..."
		echo -e "Cache size: $(du -h -d0 ~/.cache/thumbnails/large)"
		echo ''
	fi

	if [ -e ~/.cache/vmware/drag_and_drop ]; then
		echo -e "[${BLUE}>${RESET}]Checking for cached ${GREEN}drag and drop files${RESET}..."
		echo -e "Cache size: $(du -h -d0 ~/.cache/vmware/drag_and_drop)"
		echo ''
		if [ "$2" == '' ]; then
			exit
		elif [ "$2" == '-v' ] || [ "$2" == '--verbose' ]; then
			ls -laR ~/.cache/vmware/drag_and_drop
		else
			PrintUsage
			exit
		fi
	fi
elif [ "$1" == '-d' ] || [ "$1" == '--delete' ]; then

	echo -e "[${BLUE}>${RESET}]${YELLOW}Emptying trash...${RESET}"
	echo -e "Cache size: $(du -h -d0 ~/.local/share/Trash/)"
	echo ''
	find ~/.local/share/Trash -type f -print0 | xargs -0 rm -f

	if [ -e ~/.cache/thumbnails/large ]; then
		echo -e "[${BLUE}>${RESET}]${YELLOW}Deleting cached thumbnails...${RESET}"
		echo -e "Cache size: $(du -h -d0 ~/.cache/thumbnails/large)"
		echo ''
		rm -rf ~/.cache/thumbnails/large/*
	fi

	if [ -e ~/.cache/vmware/drag_and_drop ]; then
		echo -e "[${BLUE}>${RESET}]${YELLOW}Deleting cached drag and drop files...${RESET}"
		echo -e "Cache size: $(du -h -d0 ~/.cache/vmware/drag_and_drop)"
		echo ''
		rm -rf ~/.cache/vmware/drag_and_drop/*
	fi
else
	PrintUsage
fi
