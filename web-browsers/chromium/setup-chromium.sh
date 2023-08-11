#!/bin/bash

# Set "EnableMediaRouter": false, then add the following to stop mdns listener:
# chrome://flags => enable-webrtc-hide-local-ips-with-mdns => false

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

function SetupPolicies() {
	# This always creates the /etc/chromium-browser/ and /etc/opt/chrome directories,
	# symlinking the existing files over from /etc/chromium-browser/ to /etc/opt/chrome

	# https://www.chromium.org/administrators/linux-quick-start/
        sudo mkdir -p /etc/chromium-browser/policies/managed
        sudo mkdir -p /etc/chromium-browser/policies/recommended

	if [ -e /etc/chromium-browser/policies/managed/policies.json ]; then
		echo -e "[${BLUE}i${RESET}]Policy file already installed."
	elif [ -e ./chromium-policies.json ]; then
		echo -e "[${BLUE}>${RESET}]Installing policies from ./chromium-policies.json..."
		sudo tee /etc/chromium-browser/policies/managed/policies.json < ./chromium-policies.json > /dev/null
	else
        	echo -e "[${BLUE}>${RESET}]Downloading chromium-policies.json..."
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/web-browsers/chromium/chromium-policies.json' | sudo tee /etc/chromium-browser/policies/managed/policies.json > /dev/null
		# Download the latest README with examples
		echo -e "[${BLUE}>${RESET}]Downloading README.md..."
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/web-browsers/chromium/README.md' | sudo tee /etc/chromium-browser/policies/README.md > /dev/null

		if (sha256sum /etc/chromium-browser/policies/managed/policies.json | grep -qx 'ed6ecbbb6b190311e65be67771c5aa3d257dd41a19a552d3c54d96866a282418  /etc/chromium-browser/policies/managed/policies.json'); then
			echo -e "[${GREEN}OK${RESET}]"
		else
			echo -e "${RED}[\!]Bad signature for policies.json${RESET}"
		fi
	fi

	# https://support.google.com/chrome/a/answer/9027408?hl=en
	sudo mkdir -p /etc/opt/chrome 2>/dev/null
	if ! [ -e /etc/opt/chrome/policies ]; then
		sudo ln -s /etc/chromium-browser/policies /etc/opt/chrome
	fi
}

function InstallBrowser() {
	echo ""
	echo "Do you want to install the browser?"
	echo ""
	until [[ $INSTALL_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Selection: " -e -i n INSTALL_CHOICE
	done
	if [ "$INSTALL_CHOICE" == 'n' ]; then
		return 1
	fi

	echo ""
	echo "  1. Chromium snap package"
	echo "  2. Chrome using official Google repo"
	echo ""
	until [[ $BROWSER_CHOICE =~ ^(1|2)$ ]]; do
		read -rp "Selection: " BROWSER_CHOICE
	done
	if [ "$BROWSER_CHOICE" == '1' ]; then
		echo -e "[${BLUE}>${RESET}]Installing Chromium snap package..."
		sudo apt update && \
		sudo apt install -y snapd
		sudo snap install chromium
	elif [ "$BROWSER_CHOICE" == '2' ]; then

		echo -e "[${BLUE}>${RESET}]Installing Chrome official build..."

		# The deb installer for Chrome creates the following files:

		if ! [ -e /etc/apt/sources.list.d/google-chrome.list ]; then
			echo "### THIS FILE IS AUTOMATICALLY CONFIGURED ###
# You may comment out this entry, but any other modifications may be lost.
deb [arch=$(dpkg --print-architecture)] https://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
		fi
		if ! [ -e /etc/apt/trusted.gpg.d/google-chrome.gpg ]; then

			# /etc/apt/trusted.gpg.d/google-chrome.gpg
			# ----------------------------------------
			# pub   rsa4096 2016-04-12 [SC]
			#       EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796
			# uid           [ unknown] Google Inc. (Linux Packages Signing Authority) <linux-packages-keymaster@google.com>
			# sub   rsa4096 2019-07-22 [S] [expires: 2022-07-21]
			# sub   rsa4096 2021-10-26 [S] [expires: 2024-10-25]

			# Get the latest deb package from https://www.google.com/chrome/

			# Method 1 from: https://www.google.com/linuxrepositories/
			#wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -

			# Method 2 from: https://github.com/Sysinternals/SysmonForLinux/blob/main/INSTALL.md

			# This public key has the old dsa signature still attached:
			#wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > google-chrome.gpg

			# Obtaining the public key directly from a keyserver has the latest signature data without the older dsa key:
			# https://keyserver.ubuntu.com/pks/lookup?search=EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796&fingerprint=on&op=index
			gpg --keyserver hkps://keyserver.ubuntu.com:443 --recv-keys 'EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796'
			gpg --export 'EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796' | sudo tee /etc/apt/trusted.gpg.d/google-chrome.gpg > /dev/null

			sudo chown root:root /etc/apt/trusted.gpg.d/google-chrome.gpg
			sudo chmod 644 /etc/apt/trusted.gpg.d/google-chrome.gpg

			# Only check for this signature if you're using the old key
			#if ! (gpg /etc/apt/trusted.gpg.d/google-chrome.gpg | grep -P "4CCA\s?1EAF\s?950C\s?EE4A\s?B839\s?\s?76DC\s?A040\s?830F\s?7FAC\s?5991"); then echo -e "${RED}BAD SIGNATURE${RESET}"; exit; else echo -e "[${GREEN}OK${RESET}]"; fi
			if ! (gpg /etc/apt/trusted.gpg.d/google-chrome.gpg | grep -P "EB4C\s?1BFD\s?4F04\s?2F6D\s?DDCC\s?\s?EC91\s?7721\s?F63B\s?D38B\s?4796"); then echo -e "${RED}BAD SIGNATURE${RESET}"; exit; else echo -e "[${GREEN}OK${RESET}]"; fi
		fi

		sudo apt update && \
		sudo apt install -y google-chrome-stable
	fi
}

InstallBrowser
SetupPolicies

echo -e "[${BLUE}✓${RESET}]Done."
