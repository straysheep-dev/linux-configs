#!/bin/bash

if [ "${EUID}" -eq 0 ]; then
    echo "Run as a normal user. Quitting."
    exit 1
fi

if (grep -Pqx '^ID=kali$' /etc/os-release); then
	sudo apt update
	sudo apt full-upgrade -y
	sudo apt autoremove --purge -y
	sudo apt-get clean
elif (command -v apt > /dev/null); then
	sudo apt update
	sudo apt upgrade -y
	sudo apt autoremove --purge -y
	sudo apt-get clean
elif (command -v dnf > /dev/null); then
	sudo dnf upgrade -y
	sudo dnf autoremove -y
	sudo dnf clean all
fi

if (command -v snap > /dev/null); then
	true
	sudo snap refresh
fi

if (command -v flatpak > /dev/null); then
	true
	sudo flatpak update
fi

if (sudo dmesg | grep -iPq 'hypervisor'); then
	true
else
	# [BHIS | Firmware Enumeration with Paul Asadoorian](https://www.youtube.com/watch?v=G0hF76nBE7E)
	if (command -v fwupdmgr > /dev/null); then
		if (fwupdmgr --version | grep -F 'runtime   org.freedesktop.fwupd' | awk '{print $3}' | grep -P "[1-2]\.[8-9]\.[0-9]" > /dev/null); then
			fwupdmgr get-updates
			fwupdmgr update
		fi
	fi
fi
