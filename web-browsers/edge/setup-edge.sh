#!/bin/bash

# Set "EnableMediaRouter": false, then add the following to stop mdns listener:
# edge://flags => enable-webrtc-hide-local-ips-with-mdns => false

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
	# https://www.chromium.org/administrators/linux-quick-start/
	# https://techcommunity.microsoft.com/t5/discussions/global-profile-configuration-on-linux/m-p/2365884
	sudo mkdir -p /etc/opt/edge/policies/managed
	sudo mkdir -p /etc/opt/edge/policies/recommended

	if [ -e ./edge-policies.json ]; then
		echo -e "[${BLUE}>${RESET}]Installing policies from ./edge-policies.json..."
		sudo tee /etc/opt/edge/policies/managed/policies.json < ./edge-policies.json > /dev/null
	else
		echo -e "[${BLUE}>${RESET}]Downloading edge-policies.json..."
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/web-browsers/edge/edge-policies.json' | sudo tee /etc/opt/edge/policies/managed/policies.json > /dev/null
		# Download the latest README with examples
		echo -e "[${BLUE}>${RESET}]Downloading README.md..."
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/web-browsers/edge/README.md' | sudo tee /etc/opt/edge/policies/README.md > /dev/null

		if (sha256sum /etc/opt/edge/policies/managed/policies.json | grep -qx '2aa9a971c952a3fc96acc2b67eca467b5fb207d736690c31262e2347d1080813  /etc/opt/edge/policies/managed/policies.json'); then
			echo -e "[${GREEN}OK${RESET}]"
		else
			echo -e "${RED}[\!]Bad signature for policies.json${RESET}"
		fi
	fi
}

function AddEdgeRepo() {

	# https://packages.microsoft.com/
	# https://docs.microsoft.com/en-us/windows-server/administration/linux-package-repository-for-microsoft-software#package-and-repository-signing-key
	# Microsoft's GPG public key may be downloaded here: https://packages.microsoft.com/keys/microsoft.asc
	# Public Key ID: Microsoft (Release signing) gpgsecurity@microsoft.com
	# Public Key Fingerprint: BC52 8686 B50D 79E3 39D3 721C EB3E 94AD BE12 29CF

	# This source list is only for Edge, but this Microsoft GPG key works for their other Linux repositories as well
	# CLI instructions for beta and dev channels: https://www.microsoftedgeinsider.com/en-us/download
	if ! [ -e /etc/apt/sources.list.d/microsoft-edge* ]; then
		echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null
	fi

	if ! [ -e /etc/apt/trusted.gpg.d/microsoft.gpg ]; then

		# /etc/apt/trusted.gpg.d/microsoft.gpg
		# pub   rsa2048/0xEB3E94ADBE1229CF 2015-10-28 [SC]
		#       Key fingerprint = BC52 8686 B50D 79E3 39D3  721C EB3E 94AD BE12 29CF
		# uid                             Microsoft (Release signing) <gpgsecurity@microsoft.com>

		# Method from: https://github.com/Sysinternals/SysmonForLinux/blob/main/INSTALL.md
		wget -q -O - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
		sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/
		sudo chown root:root /etc/apt/trusted.gpg.d/microsoft.gpg
		sudo chmod 644 /etc/apt/trusted.gpg.d/microsoft.gpg

		if ! (gpg /etc/apt/trusted.gpg.d/microsoft.gpg | grep 'BC52 8686 B50D 79E3 39D3  721C EB3E 94AD BE12 29CF'); then
			echo -e "${RED}BAD SIGNATURE${RESET}"
			exit
		else
			echo -e "[${GREEN}OK${RESET}]"
		fi
	fi
}


function InstallEdge() {

	echo ""
	echo "Do you want to install Edge?"
	echo ""
	until [[ $INSTALL_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Selection: " -e -i n INSTALL_CHOICE
	done
	if [ "$INSTALL_CHOICE" == 'n' ]; then
		return 1
	fi

	echo ""
	echo "  1. Edge (stable)"
	echo "  2. Edge (beta)"
	echo "  3. Edge (dev)"
	echo ""
	until [[ $BROWSER_CHOICE =~ ^(1|2|3)$ ]]; do
		read -rp "Selection: " BROWSER_CHOICE
	done
	if [ "$BROWSER_CHOICE" == '1' ]; then
		AddEdgeRepo
		echo -e "[${BLUE}>${RESET}]Installing Microsoft Edge (stable)..."
		for file in /etc/apt/sources.list.d/microsoft-edge*.list; do sudo mv "$file" "/etc/apt/sources.list.d/microsoft-edge-stable.list"; done
		sudo apt update
		sudo apt install -y microsoft-edge-stable
	elif [ "$BROWSER_CHOICE" == '2' ]; then
		AddEdgeRepo
		echo -e "[${BLUE}>${RESET}]Installing Microsoft Edge (beta)..."
		for file in /etc/apt/sources.list.d/microsoft-edge*.list; do sudo mv "$file" "/etc/apt/sources.list.d/microsoft-edge-beta.list"; done
		sudo apt update
		sudo apt install -y microsoft-edge-beta
	elif [ "$BROWSER_CHOICE" == '3' ]; then
		AddEdgeRepo
		echo -e "[${BLUE}>${RESET}]Installing Microsoft Edge (dev)..."
		for file in /etc/apt/sources.list.d/microsoft-edge*.list; do sudo mv "$file" "/etc/apt/sources.list.d/microsoft-edge-dev.list"; done
		sudo apt update
		sudo apt install -y microsoft-edge-dev
	fi

}

function UninstallEdge() {

	echo ""
	echo "Do you want to uninstall Edge?"
	echo ""
	until [[ $UNINSTALL_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Selection: " -e -i n UNINSTALL_CHOICE
	done
	if [ "$UNINSTALL_CHOICE" == 'n' ]; then
		return 1
	elif [ "$UNINSTALL_CHOICE" == 'y' ]; then
		sudo apt remove microsoft-edge*
	fi

	echo ""
	echo "Remove package repository for Edge?"
	echo ""
	until [[ $REMOVE_REPO_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Selection: " -e -i n REMOVE_REPO_CHOICE
	done
	if [ "$REMOVE_REPO_CHOICE" == 'n' ]; then
		return 1
	elif [ "$REMOVE_REPO_CHOICE" == 'y' ]; then
		sudo rm /etc/apt/trusted.gpg.d/microsoft.gpg
		sudo rm /etc/apt/sources.list.d/microsoft-edge*.list
		sudo apt update
	fi


}

if ! (command -v microsoft-edge > /dev/null); then
	InstallEdge
else
	UninstallEdge
	# Policy files and directories won't be removed
	exit 0
fi

SetupPolicies

echo -e "[${BLUE}✓${RESET}]Done."
