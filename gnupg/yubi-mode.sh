#!/bin/bash

BLUE="\033[01;34m"
YELLOW="\033[01;33m"
RESET="\033[00m"

# Script to change between the pcscd daemon included with the yubioath-desktop snap, and the pcscd daemon from apt.
# Useful if you use both otp codes and gpg functions via a yubikey, yubikeys cannot access both daemons simultaneously.
# Install this script to your preferred location, with the correct permissions (root:root, 755) and add it to your PATH.

# Troubleshooting:
#
# If you're passing the yubikey through to a Linux VM from a Linux Host with usbguard, the yubikey must be allowed in the host's
# usbguard rules for the VM to read it, even if the VM can 'see' it as a device.
#
# Sometimes the yubikey can become 'stuck' in a state preventing gpg operations with the card, and the light on the card will continuously blink.
# This can happen when changing keys with different gpg identities.
# The quickest fix is to log out, log back in, then run this script again in gpg mode.

if [ "${EUID}" -eq 0 ]; then
	echo "Run this as a normal user. Sudo is used to elevate only specific commands."
	exit
fi

if (systemctl is-active --quiet usbguard); then
#	if (sudo tail /var/log/usbguard/usbguard-audit.log | grep -Pq "^.+result='SUCCESS'.+target.new='block'.+name \"YubiKey .+$"); then
	if (sudo usbguard list-devices | grep -Pq "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$"); then

		echo -e "${YELLOW}[i]usbguard service is blocking the YubiKey...${RESET}"

#		echo -e "${BLUE}[>]Remove the YubiKey...${RESET}"
#		while (lsusb | grep -q 'Yubico.com'); do
#			sleep 1
#		done

#		echo -e "${BLUE}[>]Reconnect the YubiKey...${RESET}"
#		until (sudo usbguard list-devices | grep -Pq "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$"); do 
#			sleep 1
#		done

# OPTION 1, less reliable
#		DEVICE_ID="$(sudo usbguard list-devices | grep -P "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$" | grep -oP "^\d+")"
#		sudo usbguard allow-device "$DEVICE_ID"

# OPTION 2, most reliable
		ALLOW_RULE="$(sudo usbguard list-devices | grep -P "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$" | sed 's/^[[:digit:]]\{1,3\}: block/allow/')"
		echo "$ALLOW_RULE" | sudo tee -a /etc/usbguard/rules.conf > /dev/null
		sudo systemctl restart usbguard
		echo -e "${BLUE}[✓]Device allowed.${RESET}"
	fi
else
	echo -e "${YELLOW}[i]Error modifying usbguard rules.${RESET}"
fi

if [ "${1}" == 'gpg' ]; then
	# Allows ssh, code signing, and other operations with connected yubikey
        echo -e "${BLUE}[>]GPG mode${RESET}"
	if (pgrep yubioath > /dev/null); then
		echo -e "${YELLOW}[i]Stopped runnning yubioath-desktop...${RESET}"
		pkill -f 'yubioath-desktop'
	fi
	if (systemctl is-active --quiet snap.yubioath-desktop.pcscd.service); then
	        sudo systemctl stop snap.yubioath-desktop.pcscd.service
	fi
        sudo systemctl restart pcscd

	# https://github.com/drduh/YubiKey-Guide#switching-between-two-or-more-yubikeys
	pkill gpg-agent ; pkill ssh-agent ; pkill pinentry
	#eval $(gpg-agent --daemon --enable-ssh-support)

	gpg-connect-agent "scd serialno" "learn --force" /bye
	gpg-connect-agent updatestartuptty /bye

        echo -e "${BLUE}[✓]Done.${RESET}"

elif [ "${1}" == 'otp' ]; then
	if ! (command -v yubioath-desktop); then
		echo -e "${YELLOW}[i]yubioath-desktop application not found. Quitting.${RESET}"
		exit 1
	fi

	# Connects yubikey to the yubioath-desktop snap application to view OTP codes
        echo -e "${BLUE}[>]OTP mode${RESET}"

	# This line is necessary in cases where the yubikey still cannot be read after changing pcscd daemons
	pkill gpg-agent ; pkill ssh-agent ; pkill pinentry
	#eval $(gpg-agent --daemon --enable-ssh-support)

	if (systemctl is-active --quiet pcscd); then
		sudo systemctl stop pcscd
	fi
	sudo systemctl restart snap.yubioath-desktop.pcscd.service
	echo -e "${YELLOW}[i]Starting yubioath-desktop as background process...${RESET}"
	yubioath-desktop &

        echo -e "${BLUE}[✓]Done.${RESET}"
else
        echo "Usage: yubi-mode [otp/gpg]"
fi
