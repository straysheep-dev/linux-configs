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
	# This always creates the /etc/chromium-browser/ directory
	# If /etc/opt/chrome exists, symlink the existing files over from /etc/chromium-browser/

	# https://www.chromium.org/administrators/linux-quick-start/
        sudo mkdir -p /etc/chromium-browser/policies/managed
        sudo mkdir -p /etc/chromium-browser/policies/recommended

        if [ -e ./chromium-policies.json ]; then
        	echo -e "[${BLUE}>${RESET}]Installing policies from ./chromium-policies.json..."
		sudo tee /etc/chromium-browser/policies/managed/policies.json < ./chromium-policies.json > /dev/null
	else
        	echo -e "[${BLUE}>${RESET}]Downloading chromium-policies.json..."
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/web-browsers/chromium/chromium-policies.json' | sudo tee /etc/chromium-browser/policies/managed/policies.json > /dev/null
		# Download the latest README with examples
		echo -e "[${BLUE}>${RESET}]Downloading README.md..."
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/web-browsers/chromium/README.md' | sudo tee /etc/chromium-browser/policies/README.md > /dev/null

		if (sha256sum /etc/chromium-browser/policies/managed/policies.json | grep -qx '81472d1fb8d81fe2ba38160c44064f363d6e54f1f3c0753576189e623685cd77  /etc/chromium-browser/policies/managed/policies.json'); then
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


			# Method 1 from: https://www.google.com/linuxrepositories/
			#wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -

			# Method 2 from: https://github.com/Sysinternals/SysmonForLinux/blob/main/INSTALL.md
			wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > google-chrome.gpg
			sudo mv google-chrome.gpg /etc/apt/trusted.gpg.d/
			sudo chown root:root /etc/apt/trusted.gpg.d/google-chrome.gpg
			sudo chmod 644 /etc/apt/trusted.gpg.d/google-chrome.gpg

			if ! (gpg /etc/apt/trusted.gpg.d/google-chrome.gpg | grep '4CCA 1EAF 950C EE4A B839  76DC A040 830F 7FAC 5991'); then echo -e "${RED}BAD SIGNATURE${RESET}"; exit; else echo -e "[${GREEN}OK${RESET}]"; fi
			if ! (gpg /etc/apt/trusted.gpg.d/google-chrome.gpg | grep 'EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796'); then echo -e "${RED}BAD SIGNATURE${RESET}"; exit; else echo -e "[${GREEN}OK${RESET}]"; fi
		fi

		sudo apt update && \
		sudo apt install -y google-chrome-stable
	fi
}

InstallBrowser
SetupPolicies

echo -e "[${BLUE}✓${RESET}]Done."
