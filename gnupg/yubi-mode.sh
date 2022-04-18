#!/bin/bash

BLUE="\033[01;34m"
RESET="\033[00m"

# Script to change between the pcscd daemon included with the yubioath-desktop snap, and the pcscd daemon from apt.
# Useful if you use both otp codes and gpg functions via a yubikey, yubikeys cannot access both daemons simultaneously.
# Install this script to your preferred location, with the correct permissions (root:root, 755) and add it to your PATH.

# Troubleshooting:
# Sometimes the yubikey can become 'stuck' in a state preventing gpg operations with the card, and the light on the card will continuously blink.
# This can happen when changing keys with different gpg identities.
# The quickest fix is logging out, log back in, then re-running this script in gpg mode.

if [ "${EUID}" -eq 0 ]; then
	echo "Run this as a normal user. Sudo is used to elevate only specific commands."
	exit
fi

if [ "${1}" == 'gpg' ]; then
	# Allows ssh, code signing, and other operations with connected yubikey
        echo -e "${BLUE}[>]GPG mode${RESET}"
        sudo systemctl stop snap.yubioath-desktop.pcscd.service
        sudo systemctl restart pcscd

	# https://github.com/drduh/YubiKey-Guide#switching-between-two-or-more-yubikeys
	pkill gpg-agent ; pkill ssh-agent ; pkill pinentry
	#eval $(gpg-agent --daemon --enable-ssh-support)

	gpg-connect-agent "scd serialno" "learn --force" /bye
	gpg-connect-agent updatestartuptty /bye

        echo -e "${BLUE}[i]Done.${RESET}"

elif [ "${1}" == 'otp' ]; then
	# Connects yubikey to the yubioath-desktop snap application to view OTP codes
        echo -e "${BLUE}[i]OTP mode${RESET}"

	# This line is necessary in cases where the yubikey still cannot be read after changing pcscd daemons
	pkill gpg-agent ; pkill ssh-agent ; pkill pinentry
	#eval $(gpg-agent --daemon --enable-ssh-support)

        sudo systemctl stop pcscd
        sudo systemctl restart snap.yubioath-desktop.pcscd.service

        echo -e "${BLUE}[i]Done.${RESET}"
else
        echo "Usage: yubi-mode [otp/gpg]"
fi
