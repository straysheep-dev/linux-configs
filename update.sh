#!/bin/bash

if [ "${EUID}" -eq 0 ]; then
    echo "Run as a normal user. Quitting."
    exit 1
fi

if (grep -Pqx '^ID=kali$' /etc/os-release); then
	sudo apt update && \
	sudo apt full-upgrade -y && \
	sudo apt autoremove --purge -y && \
	sudo apt-get clean
elif (command -v apt > /dev/null); then
	sudo apt update && \
	sudo apt upgrade -y && \
	sudo apt autoremove --purge -y && \
	sudo apt-get clean
elif (command -v dnf > /dev/null); then
	sudo dnf upgrade -y && \
	sudo dnf autoremove -y && \
	sudo dnf clean all
fi

if (command -v snap > /dev/null); then
	sudo snap refresh
fi

if (command -v flatpak > /dev/null); then
	#sudo flatpak update
fi
