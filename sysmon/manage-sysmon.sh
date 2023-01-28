#!/bin/bash

# MIT License

# https://github.com/Sysinternals/SysmonForLinux/blob/main/INSTALL.md
# https://www.antisyphontraining.com/getting-started-in-security-with-bhis-and-mitre-attck-w-john-strand/
# https://github.com/angristan/wireguard-install

RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings
BLUE="\033[01;34m"     # Information
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

function IsRoot() {

	# Root EUID check
	if [ "${EUID}" -eq 0 ]; then
		echo -e "You need to run this script as a ${GREEN}normal user${RESET}."
		exit 1
	fi

}
IsRoot

function checkOS() {

	# Check OS version
	OS="$(grep -E "^ID=" /etc/os-release | cut -d '=' -f 2)"

	if [[ $OS == "ubuntu" ]]; then
		CODENAME="$(grep VERSION_CODENAME /etc/os-release | cut -d '=' -f 2)" # debian or ubuntu
		echo -e "${BLUE}[i]$OS $CODENAME detected.${RESET}"
		MAJOR_UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2 | cut -d '.' -f 1)
		if [[ $MAJOR_UBUNTU_VERSION -lt 18 ]] || [[ $MAJOR_UBUNTU_VERSION -gt 21 ]]; then
			echo "Your version of Ubuntu is not supported."
			exit 1
		fi
	fi
}
checkOS

function InstallSysmon() {
	echo -e "${BLUE}[i]Obtaining Microsoft signing key...${RESET}"
	wget -q https://packages.microsoft.com/config/ubuntu/"$(lsb_release -rs)"/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	sudo dpkg -i packages-microsoft-prod.deb

	echo -e "${BLUE}[>]Updating apt and installing Sysmon...${RESET}"
	sudo apt update
	sudo apt install sysmonforlinux -y

	echo -e "${BLUE}[>]Starting Sysmon service...${RESET}"
	# -i can optionally take a config file
	sudo sysmon -accepteula -i

	systemctl status sysmon

	echo -e "${GREEN}[i]Done."
}

function UninstallSysmon() {
	echo -e "${BLUE}[>]Stopping and uninstalling Sysmon...${RESET}"
	sudo sysmon -u force
	sudo apt autoremove --purge -y sysmonforlinux

	echo -e "${BLUE}[>]Removing Microsoft signing key...${RESET}"
	sudo apt autoremove --purge -y packages-microsoft-prod

	echo -e "${GREEN}[i]Done.${RESET}"
}

echo -e "   ${BOLD}Sysmon management script${RESET}"
if (systemctl is-active auditd > /dev/null) || (systemctl is-enabled auditd > /dev/null); then
	echo -e "${YELLOW}[i]auditd is active or enabled on this system. Do you want to stop and disable it first?${RESET}"
	until [[ $AUDITD_CHOICE =~ ^(y|n)$ ]]; do
	read -rp "Enter [y/n]: " -e AUDITD_CHOICE
		done
	if [[ $AUDITD_CHOICE == "y" ]]; then
		sudo systemctl stop auditd
		sudo systemctl disable auditd
		sudo systemctl mask auditd
	elif [[ $AUDITD_CHOICE == "n" ]]; then
		true
	fi
fi
if (systemctl is-active sysmon > /dev/null); then
	echo -e "${GREEN}   Sysmon is currrently running.${RESET}"
	echo ""
	echo -e "   ${BOLD}Examples${RESET}:"
	echo "     [Terminal 1]: sudo tail -f /var/log/syslog | sudo /opt/sysmon/sysmonLogView | grep example.txt"
	echo "     [Termianl 2]: touch example.txt"
	echo ""
	echo "     [Terminal 1]: sudo tail -f /var/log/syslog | sudo /opt/sysmon/sysmonLogView | grep '127.0.0.1'"
	echo "     [Terminal 2]: ping 127.0.0.1"
	echo ""
elif ! (systemctl is-active sysmon > /dev/null) && (command -v sysmon > /dev/null); then
	echo -e "${YELLOW}   Sysmon is installed, but inactive.${RESET}"
fi
echo -e "   ${BOLD}What would you like to do?${RESET}"
echo -e ""
echo -e "   1) Install / Start Sysmon"
echo -e "   2) Uninstall Sysmon"
echo -e "   3) Exit"
echo -e ""
until [[ $MENU_CHOICE =~ ^(1|2|3)$ ]]; do
	read -rp "Enter [1/2/3]: " -e MENU_CHOICE
done
if [[ $MENU_CHOICE == "1" ]]; then
	if (command -v sysmon > /dev/null) && ! (systemctl is-active sysmon > /dev/null); then
		echo -e "${BLUE}[>]Starting Sysmon...${RESET}"
		sudo sysmon -accepteula -i
		echo ""
		systemctl status sysmon
	elif (command -v sysmon > /dev/null); then
		echo -e "${BLUE}[i]Sysmon already installed. Quitting.${RESET}"
		exit
	else
		InstallSysmon
	fi
elif  [[ $MENU_CHOICE == "2" ]]; then
	if ! (command -v sysmon > /dev/null); then
		echo -e "${BLUE}[i]Sysmon not installed. Quitting.${RESET}"
		exit
	else
		UninstallSysmon
	fi
elif [[ $MENU_CHOICE == "3" ]]; then
	exit
fi
