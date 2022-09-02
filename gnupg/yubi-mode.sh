#!/bin/bash

BLUE="\033[01;34m"
YELLOW="\033[01;33m"
RESET="\033[00m"

# https://github.com/Yubico/yubioath-desktop/releases
# https://snapcraft.io/yubioath-desktop

# https://developers.yubico.com/yubioath-desktop/Releases/yubioath-desktop-5.1.0-linux.AppImage
# https://developers.yubico.com/yubioath-desktop/Releases/yubioath-desktop-5.1.0-linux.AppImage.sig

# $ sudo apt-add-repository ppa:yubico/stable
# $ sudo apt update
# $ sudo apt install <package>
# $ sudo apt install yubikey-manager # https://github.com/Yubico/yubioath-desktop#cli
# $ ykman oath accounts code [OPTIONS] [QUERY]

# $ sudo snap install yubioath-desktop

# Signing key for AppImage: 9E88 5C03 02F9 BB91 6752  9C2D 5CBA 11E6 ADC7 BCD1
# Signing key for Yubico PPA: 3653 E210 64B1 9D13 4466  702E 43D5 C495 32CB A1A9

# Script to change between physical yubikeys, with same or differing identities.
# It also handles arbitration between the pcscd daemon included with the yubioath-desktop snap, and the pcscd daemon from apt.
# Useful if you use both oath codes and gpg functions via a yubikey and the snap. Both daemons cannot run simultaneously.
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
	if (usbguard list-devices | grep -Pq "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$"); then

		echo -e "${YELLOW}[i]usbguard service is blocking the YubiKey...${RESET}"

# These next steps are not necessary (on ubuntu at least) and are only here for reference.
#		echo -e "${BLUE}[>]Remove the YubiKey...${RESET}"
#		while (lsusb | grep -q 'Yubico.com'); do
#			sleep 1
#		done

#		echo -e "${BLUE}[>]Reconnect the YubiKey...${RESET}"
#		until (usbguard list-devices | grep -Pq "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$"); do
#			sleep 1
#		done

# OPTION 1, less reliable
#		DEVICE_ID="$(usbguard list-devices | grep -P "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$" | grep -oP "^\d+")"
#		sudo usbguard allow-device "$DEVICE_ID"

# OPTION 2, most reliable
		ALLOW_RULE="$(usbguard list-devices | grep -P "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$" | sed 's/^[[:digit:]]\{1,3\}: block/allow/')"
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
	# Want to limit the use of sudo in the shell by checking if services need started or stopped
	# This allows switching keys without sudo.
	# pcscd from apt is always required, so stop the snap version if it's detected.
	if (systemctl is-active --quiet snap.yubioath-desktop.pcscd.service); then
		if ! (sudo systemctl stop snap.yubioath-desktop.pcscd.service); then
			echo "Sudo canceled by user. Quitting."
			exit 1
		fi
	fi
	# Start pcscd if it's not running.
	if ! (systemctl is-active --quiet pcscd); then
		if ! (sudo systemctl restart pcscd); then
			echo "Sudo canceled by user. Quitting."
			exit 1
		fi
	fi

	# https://github.com/drduh/YubiKey-Guide#switching-between-two-or-more-yubikeys
	pkill gpg-agent ; pkill ssh-agent ; pkill pinentry
	#eval $(gpg-agent --daemon --enable-ssh-support)

	gpg-connect-agent "scd serialno" "learn --force" /bye
	gpg-connect-agent updatestartuptty /bye

        echo -e "${BLUE}[✓]Done.${RESET}"

elif [ "${1}" == 'oath' ]; then

        echo -e "${BLUE}[>]oath mode${RESET}"

	# This line is necessary in cases where the yubikey still cannot be read after changing pcscd daemons
	pkill gpg-agent ; pkill ssh-agent ; pkill pinentry
	#eval $(gpg-agent --daemon --enable-ssh-support)

	# Check if user has the snap package installed
	if [ -e /snap/bin/yubioath-desktop ]; then
		# Connects yubikey to the yubioath-desktop snap application pcscd service to view oath codes
		if (systemctl is-active --quiet pcscd); then
			if ! (sudo systemctl stop pcscd); then
				echo "Sudo canceled by user. Quitting."
				exit 1
			fi
		fi
		if ! (systemctl is-active --quiet snap.yubioath-desktop.pcscd.service); then
			if ! (sudo systemctl restart snap.yubioath-desktop.pcscd.service); then
				echo "Sudo canceled by user. Quitting."
				exit 1
			fi
		fi
	fi

	if (pgrep -f 'yubioath-desktop'); then
		echo -e "${BLUE}[i]${RESET}yubioath-desktop already running."
	elif (command -v yubioath-desktop > /dev/null); then
		echo -e "${YELLOW}[i]Starting yubioath-desktop as background process...${RESET}"
		yubioath-desktop &
	else
		# If not in PATH as 'yubioath-desktop', check for AppImage file
		echo -e "${YELLOW}[i]${RESET}'yubioath-desktop' not found in PATH!"
		echo -e "${YELLOW}[>]${RESET}Searching for yubioath-desktop-* (AppImage)..."
		# Search entire filesystem, redirect the 'Permission denied' errors to /dev/null, we don't need to read those directories and this error can be safely ignored.
		# Safely handle dangerous filenames with print0 | xargs -0 <command>
		# ls prints everything on one line, use sed to replace spaces with newlines
		if (find / -type f -name "yubioath-desktop-*" -print0 2>/dev/null | xargs -0 ls | sed 's/ /\n/g'); then
			echo -e "${BLUE}[i]${RESET}FOUND. Add the above application itself or a symlink to it in your PATH as 'yubioath-desktop'"
		else
			echo -e "${YELLOW}[i]${RESET}Cannot find yubioath-desktop applicaton. Quitting."
		fi
		exit 0
	fi

        echo -e "${BLUE}[✓]Done.${RESET}"

	sleep 3

	# Close this shell once the GUI application is running
	exit 0
else
        echo "Usage: yubi-mode [oath/gpg]"
fi
