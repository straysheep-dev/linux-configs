#!/bin/bash

# Applies apparmor to firefox-esr, and configures rkhunter

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

AA_FIREFOX='usr.bin.firefox-esr'
AA_DIR='/etc/apparmor.d/'
AA_FIREFOX_PATH="/etc/apparmor.d/$AA_FIREFOX"
AA_FIREFOX_BROWSERS_PATH='/etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox-esr'
AA_FIREFOX_LOCAL_PATH='/etc/apparmor.d/local/usr.bin.firefox-esr'
RKHUNTER_CONF='/etc/rkhunter.conf'

if [ "${EUID}" -ne 0 ]; then
	echo "You need to run this script as root. Quitting."
	exit 1
fi

function updateAppArmor() {
	echo "======================================================================"
	echo -e "${BLUE}[i]${RESET}Checking Firefox AppArmor profile..."

	# Ensure other apparmor utilities are installed
	apt install -y apparmor-utils apparmor-profiles apparmor-profiles-extra

	# For latest firefox apparmor profile:
	# https://bazaar.launchpad.net/~mozillateam/firefox/firefox.focal/view/head:/debian/usr.bin.firefox.apparmor.14.10

	if [[ -e "$AA_DIR"/disable/"$AA_FIREFOX" ]]; then
		rm "$AA_DIR"/disable/"$AA_FIREFOX"
	fi

	# /etc/apparmor.d/usr.bin.firefox-esr
	if ! [ -e "$AA_FIREFOX_PATH" ]; then
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/apparmor/apparmor-usr.bin.firefox-esr' > "$AA_FIREFOX_PATH"
		if ! (sha256sum "$AA_FIREFOX_PATH" | grep "eb3f9e1632e7717d5ce2eea64cbc0af43a6131345d47946a6991300a47b5a85b  $AA_FIREFOX_PATH"); then
			echo -e "${RED}[X]Bad checksum. Quitting...${RESET}"
			exit 1
		else
			echo -e "${GREEN}[OK]$AA_FIREFOX_PATH${RESET}"
		fi
	fi

	# /etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox-esr
	if ! [ -e "$AA_FIREFOX_BROWSERS_PATH" ]; then
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/apparmor/apparmor-firefox.abstractions' > "$AA_FIREFOX_BROWSERS_PATH"
		if ! (sha256sum "$AA_FIREFOX_BROWSERS_PATH" | grep "e712b2f363663db162c804ee57d8e3e6ef983d3f0caa2dea69974d3edc086c7e  $AA_FIREFOX_BROWSERS_PATH"); then
			echo -e "${RED}[X]Bad checksum. Quitting...${RESET}"
			exit 1
		else
			echo -e "${GREEN}[OK]$AA_FIREFOX_BROWSERS_PATH${RESET}"
		fi
	fi

	# /etc/apparmor.d/local/usr.bin.firefox-esr
	if ! [ -e "$AA_FIREFOX_LOCAL_PATH" ]; then
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/apparmor/apparmor-usr.bin.firefox.local' > "$AA_FIREFOX_LOCAL_PATH"
		if ! (sha256sum "$AA_FIREFOX_LOCAL_PATH" | grep "bcfa36de8bfc0f6063beb107bdf98af515f40fea53a7bca249658d21a0d2234a  $AA_FIREFOX_LOCAL_PATH"); then
			echo -e "${RED}[X]Bad checksum. Quitting...${RESET}"
			exit 1
		else
			echo -e "${GREEN}[OK]$AA_FIREFOX_LOCAL_PATH${RESET}"
		fi
	fi

	if ! (systemctl is-active apparmor); then 
		systemctl enable apparmor.service && systemctl start apparmor.service
		echo -e "${BLUE}[i]${RESET}Enabling apparmor.service..."
	fi

	apparmor_parser -r "$AA_FIREFOX_PATH"
	
	echo -e "${BLUE}[i]${RESET}AppArmor Status:"
	aa-status | grep -i 'firefox'
}
updateAppArmor

function setRkhunter() {

	# Ensure rkhunter is installed
	apt install -y rkhunter

	echo "======================================================================"
	echo -e "${BLUE}[i]${RESET}Configuring rkhunter..."

	# Stop cron from executing this daily and overwriting the hash db
	echo -e "${BLUE}[i]${RESET}Stopping cron.daily from executing rkhunter..."
	chmod -x '/etc/cron.daily/rkhunter'

	if [ -e "$RKHUNTER_CONF" ]; then
		if ! (grep -q -x "DISABLE_TESTS=suspscan hidden_procs deleted_files apps" "$RKHUNTER_CONF"); then
			sed -i 's/^DISABLE_TESTS=.*$/DISABLE_TESTS=suspscan hidden_procs deleted_files apps/' "$RKHUNTER_CONF" 
			echo -e "${BLUE}[*]${RESET}Updating rkhunter test list."
		fi
		if ! (grep -q -x "SCRIPTWHITELIST=/usr/bin/egrep" "$RKHUNTER_CONF"); then
			sed -i 's/#SCRIPTWHITELIST=\/usr\/bin\/egrep/SCRIPTWHITELIST=\/usr\/bin\/egrep/' "$RKHUNTER_CONF"
			echo -e "${BLUE}[*]${RESET}Updating script whitelists. (1/6)"
		fi
		if ! (grep -q -x "SCRIPTWHITELIST=/usr/bin/fgrep" "$RKHUNTER_CONF"); then
			sed -i 's/#SCRIPTWHITELIST=\/usr\/bin\/fgrep/SCRIPTWHITELIST=\/usr\/bin\/fgrep/' "$RKHUNTER_CONF"
			echo -e "${BLUE}[*]${RESET}Updating script whitelists. (2/6)"
		fi
		if ! (grep -q -x "SCRIPTWHITELIST=/usr/bin/which" "$RKHUNTER_CONF"); then
			sed -i 's/#SCRIPTWHITELIST=\/usr\/bin\/which/SCRIPTWHITELIST=\/usr\/bin\/which/' "$RKHUNTER_CONF"
			echo -e "${BLUE}[*]${RESET}Updating script whitelists. (3/6)"
		fi
		if ! (grep -q -x "SCRIPTWHITELIST=/usr/bin/ldd" "$RKHUNTER_CONF"); then
			sed -i 's/#SCRIPTWHITELIST=\/usr\/bin\/ldd/SCRIPTWHITELIST=\/usr\/bin\/ldd/' "$RKHUNTER_CONF"
			echo -e "${BLUE}[*]${RESET}Updating script whitelists. (4/6)"
		fi
		if [ "$VPS" = 'false' ]; then
			if ! (grep -q -x "SCRIPTWHITELIST=/usr/bin/lwp-request" "$RKHUNTER_CONF"); then
				sed -i 's/#SCRIPTWHITELIST=\/usr\/bin\/lwp-request/SCRIPTWHITELIST=\/usr\/bin\/lwp-request/' "$RKHUNTER_CONF"
				echo -e "${BLUE}[*]${RESET}Updating script whitelists. (5/6)"
			fi
		fi
		# Kali specific
		if (grep -qx 'ID=kali' /etc/os-release); then
			if ! (grep -q -x "#/usr/bin/which.debianutils" "$RKHUNTER_CONF"); then
				sed -i 's/SCRIPTWHITELIST=\/usr\/bin\/which.debianutils/#SCRIPTWHITELIST=\/usr\/bin\/which.debianutils/' "$RKHUNTER_CONF"
				echo -e "${BLUE}[*]${RESET}Updating script whitelists. (6/6)"
			fi
		fi
		if ! (grep -q -x "ALLOW_SSH_PROT_V1=0" "$RKHUNTER_CONF"); then
			sed -i 's/ALLOW_SSH_PROT_V1=2/ALLOW_SSH_PROT_V1=0/' "$RKHUNTER_CONF"
			echo -e "${BLUE}[*]${RESET}Adding warning for detection of SSHv1 protocol."
		fi
		if ! (grep -q -x '#WEB_CMD="/bin/false"' "$RKHUNTER_CONF"); then
			sed -i 's/WEB_CMD="\/bin\/false"/#WEB_CMD="\/bin\/false"/' "$RKHUNTER_CONF"
			echo -e "${BLUE}[*]${RESET}Commenting out WEB_CMD="'"\/bin\/false"'
		fi
		rkhunter -C && echo -e "${GREEN}[+]${RESET}Reloading rkhunter profile."
		rkhunter --propupd
		echo "======================================================================"
		echo -e "${BLUE}[v]${RESET}rkhunter database hashes:"
		sha256sum /var/lib/rkhunter/db/rkhunter.dat*
	elif ! [ -e "$RKHUNTER_CONF" ]; then
		echo -e "${RED}"'[!]'"${RESET}rkhunter.conf file not found. Skipping."
	fi
}
setRkhunter
