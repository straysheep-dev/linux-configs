#!/bin/bash

# Checks the official go website for the latest version + hash and downloads it.

# shellcheck disable=SC2016
# shellcheck disable=SC1091

DL='https://go.dev/dl/'
GO_INFO='/tmp/go-downloads.txt'

function GetGoInformation() {

	# Download everything to /tmp
	cd /tmp || exit

	# Check to see if we already ran this script and have the information locally
	if ! [ -e "$GO_INFO" ]; then
		echo "[*]Getting latest go version information..."
		if ! (curl -sS "$DL" > "$GO_INFO"); then
			echo "[i]Error obtaining go information. Quitting."
			rm "$GO_INFO"
			exit 1
		fi
	fi
}

function CheckCurrentVersion() {

	if (command -v go > /dev/null); then
		GO_VER_CURRENT="$(go version | grep -oP "go\d+\.\d+\.(\d+)?")"
		GO_BIN='go'
	elif [ -d /usr/local/go ]; then
		GO_VER_CURRENT="$(/usr/local/go/bin/go version | grep -oP "go\d+\.\d+\.(\d+)?")"
		GO_BIN='/usr/local/go/bin/go'
	elif ! [ -d /usr/local/go ]; then
		echo "[i]go not found in current PATH or in /usr/local/go..."
	fi

}

function GetGo() {
	echo "go version: $GO_LINUX_AMD64"
	echo "sha256sum: $GO_LINUX_AMD64_HASH"
	echo ""

	# Check to see if we already ran this script and have the binary locally
	if ! [ -e /tmp/"$GO_LINUX_AMD64" ]; then
		echo "[*]Downloading latest go binary..."
		curl -LsSO "$DL""$GO_LINUX_AMD64"
	fi

	if (sha256sum "$GO_LINUX_AMD64" | grep -i "$GO_LINUX_AMD64_HASH"); then
		echo "[i]OK"
	else
		echo "[i]Bad checksum, quitting..."
		exit 1
	fi
}


function InstallGo() {

	echo "[*]Installing and adding $GO_LINUX_AMD64 to PATH..."

	# https://go.dev/doc/install
	sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/"$GO_LINUX_AMD64"
	{
	echo ''
	echo '# set PATH so it includes go installation if it exists'
	echo 'if [ -d "/usr/local/go" ] ; then'
	echo '    PATH="$PATH:/usr/local/go/bin"'
	echo 'fi'
	} | sudo tee /etc/profile.d/go-path.sh

	source /etc/profile.d/go-path.sh

	echo "installed: $(go version)"
	sleep 1
	echo "[i]Reboot for /etc/profile.d PATH changes to take effect."

}


# Everything below checks if go is already installed, and either installs it or updates it.

CheckCurrentVersion
GetGoInformation

GO_VER_LATEST="$(grep 'Stable versions' -A 3 "$GO_INFO" | grep -oP "go\d+\.\d+\.(\d+)?")"
GO_LINUX_AMD64="$GO_VER_LATEST"'.linux-amd64.tar.gz'
GO_LINUX_AMD64_HASH="$(grep "$GO_LINUX_AMD64" -A 5 "$GO_INFO" | grep -oP "\b(\w){64}\b")"

if [ "$GO_VER_CURRENT" == '' ]; then
	GetGo
	InstallGo
elif [ "$GO_VER_LATEST" == "$GO_VER_CURRENT" ]; then
	echo "[i]You're on the latest version: $("$GO_BIN" version)"
	exit
else
	GetGo
	InstallGo
fi
