#!/bin/bash

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset


# Installation and setup of general security tools
# TO DO: use git + chmod -R $USERNAME:$USERNAME to make /opt directories writable and updatable, and also return them read-only permissions by root and $USERNAME after updating.

if [ "${EUID}" -eq 0 ]; then
	echo "You need to run this script as a normal user"
	exit 1
fi

function MakeTemp() {

	# Make a temporary working directory

	if ! [ -d /tmp/tools ]; then
		mkdir /tmp/tools
	fi

	SETUPDIR=/tmp/tools
	export SETUPDIR

	cd "$SETUPDIR" || exit 1
	echo -e "${BLUE}[i]Changing working directory to $SETUPDIR${RESET}"

}


function InstallAptPackages() {
	echo -e "${BLUE}[i]Installing tools from apt...${RESET}"

	sudo apt update && sudo apt full-upgrade -y

	sudo apt install \
	beef-xss \
	bettercap \
	binwalk \
	bloodhound \
	braa \
	burpsuite \
	cherrytree \
	cifs-utils \
	cntlm \
	crackmapexec \
	crunch \
	curl \
	de4dot \
	dirb \
	dirbuster \
	dos2unix \
	dsniff \
	enum4linux \
	evil-winrm \
	exploitdb \
	feroxbuster \
	gobuster \
	hashcat \
	hashid \
	hash-identifier \
	hexedit \
	hping3 \
	hydra \
	impacket-scripts \
	john \
	libimage-exiftool-perl \
	libssl-dev \
	mariadb-client-core-10.6 \
	masscan \
	mimikatz \
	mingw-w64 \
	nbtscan \
	ncrack \
	netdiscover \
	nikto \
	nishang \
	nmap \
	onesixtyone \
	oscanner \
	p7zip \
	p7zip-rar \
	pdfid \
	pipx \
	poppler-utils \
	powercat \
	powershell \
	powershell-empire \
	powersploit \
	proxychains \
	python3-pip \
	python3-scapy \
	python3-venv \
	rdesktop \
	redis-tools \
	ridenum \
	screen \
	shellter \
	smbclient \
	smbmap \
	smtp-user-enum \
	snapd \
	snmp \
	snmpcheck \
	sqlmap \
	ssdeep \
	ssh-audit \
	sshuttle \
	sslscan \
	thc-ipv6 \
	tmux \
	tnscmd10g \
	tshark \
	webshells \
	wfuzz \
	whatweb \
	windows-binaries \
	wireshark \
	wkhtmltopdf
	# Bottom entry loses the trailing '\'

	# TO DO: rewrite this to handle missing or renamed (updated) packages

	#smb-nat \
	#golang-1.17 \
	#gvncviewer \
	#exploitdb-bin-sploits \
	#kazam \
	#svwar \ does not exist -> could be sipvicious/kali-rolling 0.3.3-2 all

	if [ "$?" -ne '0' ]; then
		exit
	fi

	sudo apt autoremove --purge -y 
	sudo apt-get clean

	sleep 3

}

function AddAliases() {

	# Two wireshark windows are useful for monitoring two network interfaces in real time
	if ! (grep -q "alias dualshark='wireshark&;wireshark&'" "$HOME"/.zshrc); then
		echo -e "${BLUE}[i]${RESET}Adding custom aliases..."
		{
		echo ""
		echo "# alias for visibility while scanning"
		echo "alias dualshark='wireshark&;wireshark&'"
		} >> "$HOME"/.zshrc
	fi

}

function InstallSnaps() {

	# /etc/profile.d/apps-bin-path.sh SHOULD add snap bins to PATH, check for snaps in PATH anyway:
	if ! (echo "$PATH" | grep -q '/snap/bin'); then
		echo -e "${BLUE}[i]Adding /snap/bin to PATH...${RESET}"

		{
		echo ''
		echo '# set PATH so it includes snap packages if they exist'
		echo 'if [ -d "/snap/bin/" ]; then'
		echo '    PATH="$PATH:/snap/bin"'
		echo 'fi'
		} > "$SETUPDIR"/snap-path.sh

		sudo cp "$SETUPDIR"/snap-path.sh /etc/profile.d/snap-path.sh && \
		rm "$SETUPDIR"/snap-path.sh

		source /etc/profile.d/snap-path.sh
	fi

	echo -e "${BLUE}[i]Refreshing snaps...${RESET}"
	sudo snap refresh

	echo -e "${BLUE}[i]Installing snap packages...${RESET}"
	sudo snap install chromium
	sudo snap install libreoffice
	sudo snap disconnect libreoffice:network > /dev/null
	sudo snap install vlc
	sudo snap disconnect vlc:network > /dev/null

}

function InstallPypiPackages() {

	echo -e "${BLUE}[i]Installing PyPi tools...${RESET}"

# pipenv
#	TO DO

# pipx
#	if ! [ -e '/home/kali/.local/bin/pipx' ]; then
#		python3 -m pip install --user pipx
#		python3 -m pipx ensurepath
#	fi

	# applications install with pipx
	if ! (command -v autorecon > /dev/null);then
		pipx install git+https://github.com/Tib3rius/AutoRecon.git
	else
		echo "[i]AutoRecon installed."
	fi
	if ! (command -v mitm6 > /dev/null); then
		pipx install git+https://github.com/dirkjanm/mitm6.git
	else
		echo "[i]mitm6 installed."
	fi
	if ! (command -v graphqlmap > /dev/null); then
		pipx install git+https://github.com/swisskyrepo/GraphQLmap.git
		pipx inject graphqlmap requests
	else
		echo "[i]GraphQLmap installed."
	fi

# pip
	# libararies installed with pip
	python3 -m pip install --user beautifulsoup4 lxml requests
	python3 -m pip install --user paramiko

# pip venv
#	cd "$HOME" || exit
#
#	if ! [ -e "$HOME"/venv/bin/activate ]; then
#		mkdir "$HOME"/venv
#		python3 -m venv ~/venv
#	fi
#
#	source "$HOME"/venv/bin/activate
#
#	python3 -m pip install mitm6
#	python3 -m pip install --pre scapy[basic]
#	python3 -m pip install ldapdomaindump
#	python3 -m pip install matplotlib
#	python3 -m pip install cryptography
#	python3 -m pip install paramiko
#	python3 -m pip install pyx
#	python3 -m pip install beautifulsoup4 lxml requests
#	python3 -m pip install --upgrade xlrd
#
#	deactivate
#
#	cd "$HOME" || exit

}

function InstallGems() {

	echo -e "${BLUE}[i]Installing gems...${RESET}"

# evil-winrm is now available via apt
#	if ! (command -v evil-winrm > /dev/null); then
#		gem install evil-winrm --user-install
#	fi

	if ! [ -e /etc/profile.d/go-path.sh ]; then
		echo -e "${BLUE}[i]Adding gems to PATH...${RESET}"

		{
		echo ''
		echo '# set PATH so it includes user local ruby gems if they exist'
		echo 'if [ -d "$HOME/.local/share/gem/ruby/2.7.0/bin/" ]; then'
		echo '    PATH="$PATH:$HOME/.local/share/gem/ruby/2.7.0/bin"'
		echo 'fi'
		} > "$SETUPDIR"/gem-path.sh

		sudo cp "$SETUPDIR"/gem-path.sh /etc/profile.d/gem-path.sh && \
		rm "$SETUPDIR"/gem-path.sh
		source /etc/profile.d/gem-path.sh
	fi
	echo -e "${BLUE}[i]Done.${RESET}"

}

function InstallGo() {

	if ! (command -v go > /dev/null); then
		echo -e "${BLUE}[i]Installing golang...${RESET}"
		sudo apt -y install golang-1.17
	fi

	echo -e "${BLUE}[i]Adding go to PATH...${RESET}"

	if ! [ -e /etc/profile.d/go-path.sh ]; then
		{
		echo ''
		echo '# set PATH so it includes go installation if it exists'
		echo 'if [ -d "/usr/local/go" ] ; then'
		echo '    PATH="$PATH:/usr/local/go/bin"'
		echo 'fi'
		} > "$SETUPDIR"/go-path.sh

		sudo cp "$SETUPDIR"/go-path.sh /etc/profile.d/go-path.sh

		source /etc/profile.d/go-path.sh
	fi

	# Don't want to always script this, give user the option
	echo -e "${YELLOW}[i]Use 'sudo visudo' to add '/usr/local/go/bin:' to the 'secure_path=...' variable${RESET}"

	go --version
	sleep 2

}

function InstallExternalTools() {

	cd "$SETUPDIR" || exit

	# Individual wordlists
	if ! [ -e /opt/wordlists ]; then
		echo -e "${BLUE}[i]Downloading wordlists...${RESET}"
		mkdir "$SETUPDIR"/wordlists
		cd "$SETUPDIR"/wordlists || exit

		# Top Usernames (shortlist)
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/top-usernames-shortlist.txt'

		# Common Passwords (Top 10000)
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/10-million-password-list-top-10000.txt'

		# ncrack lists, formatted and copied here
		if (command -v ncrack); then
			grep -Pv "^(#|$)" /usr/share/ncrack/default.usr > "$SETUPDIR"/wordlists/ncrack-default.usr
			grep -Pv "^(#|$)" /usr/share/ncrack/default.pwd > "$SETUPDIR"/wordlists/ncrack-default.pwd
			grep -Pv "^(#|$)" /usr/share/ncrack/top50000.pwd > "$SETUPDIR"/wordlists/ncrack-top50000.pwd
		fi

		# rockyou
		if [ -e /usr/share/wordlists/rockyou.txt.gz ]; then
			cp /usr/share/wordlists/rockyou.txt.gz .
			gunzip ./rockyou.txt.gz
		fi

		# Single Names ~10k
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/Names/names.txt'

		# Common Web Content
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt'

		# Web Content (default wordlist for Feroxbuster)
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-medium-directories.txt'
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-large-directories.txt'
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-large-files.txt'

		# SNMP Community Strings
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/SNMP/snmp-onesixtyone.txt'

		echo -e "${BLUE}[i]Done.${RESET}"
	fi

	# SecLists
	# https://github.com/danielmiessler/SecLists
	if ! [ -e /opt/wordlists/SecLists ]; then
		cd "$SETUPDIR"/ || exit
		echo -e "${BLUE}[i]Downloading SecLists...${RESET}"
		git clone --depth 1 'https://github.com/danielmiessler/SecLists.git'
	fi

	# Statistically Likely Usernames
	# https://github.com/insidetrust/statistically-likely-usernames
	if ! [ -e /opt/wordlists/statistically-likely-usernames ]; then
		echo -e "${BLUE}[i]Downloading Statistically Likely Usernames...${RESET}"
		cd "$SETUPDIR"/ || exit
		git clone 'https://github.com/insidetrust/statistically-likely-usernames.git'
	fi

	# Cutter (AppImage)
	# https://github.com/rizinorg/cutter/releases/latest
	if ! [ -e /opt/Cutter ]; then
		echo -e "${BLUE}[i]Downloading Cutter AppImage...${RESET}"
		mkdir "$SETUPDIR"/Cutter
		cd "$SETUPDIR"/Cutter || exit
		curl -sSLO 'https://github.com/rizinorg/cutter/releases/download/v2.0.5/Cutter-v2.0.5-x64.Linux.AppImage'
		if (sha256sum ./Cutter-v2.0.5-x64.Linux.AppImage | grep '453b0d1247f0eab0b87d903ce4995ff54216584c5fd5480be82da7b71eb2ed3d'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi

	fi

	# IDA Free
	# https://hex-rays.com/ida-free/
	# https://out7.hex-rays.com/files/idafree77_linux.run
	# SHA1: 42038657317ebea44954b484a236e7f8cbc7d2fa

	# Nessus
	# https://www.tenable.com/downloads/

	#================ Pause before continuing ==================
	until [[ $CONTINUE_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Continue? [y/n]: " -e -i y CONTINUE_CHOICE
	done
	if [ "$CONTINUE_CHOICE" == 'n' ]; then
		echo "Check $SETUPDIR before running again. Quitting."
		exit 1
	fi
	CONTINUE_CHOICE=''
	#================ Pause before continuing ==================

	# chisel (binaries)
	CHISEL_VER='v1.7.7'
	if ! [ -e /opt/chisel ]; then
		echo -e "${BLUE}[i]Downloading Chisel $CHISEL_VER binaries...${RESET}"
		mkdir "$SETUPDIR"/chisel
		cd "$SETUPDIR"/chisel || exit
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_checksums.txt
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_darwin_amd64.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_darwin_arm64.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_386.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_amd64.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_arm64.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_armv6.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_armv7.gz
		echo "[i][#########33%                    ]"
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_mips64le_hardfloat.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_mips64le_softfloat.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_mips64_hardfloat.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_mips64_softfloat.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_mipsle_hardfloat.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_mipsle_softfloat.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_mips_hardfloat.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_mips_softfloat.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_ppc64.gz
		echo "[i][###################66%          ]"
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_ppc64le.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_linux_s390x.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_windows_386.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_windows_amd64.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_windows_arm64.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_windows_armv6.gz
		curl -sSLO https://github.com/jpillora/chisel/releases/download/"$CHISEL_VER"/chisel_1.7.7_windows_armv7.gz
		curl -sSLO https://github.com/jpillora/chisel/archive/refs/tags/"$CHISEL_VER".zip
		curl -sSLO https://github.com/jpillora/chisel/archive/refs/tags/"$CHISEL_VER".tar.gz
		echo "[i][###########################100%]"

		if (sha256sum -c ./chisel_1.7.7_checksums.txt); then
			echo -e "${GREEN}[OK chisel_1.7.7_checksums]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
	fi

	#================ Pause before continuing ==================
	until [[ $CONTINUE_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Continue? [y/n]: " -e -i y CONTINUE_CHOICE
	done
	if [ "$CONTINUE_CHOICE" == 'n' ]; then
		echo "Check $SETUPDIR before running again. Quitting."
		exit 1
	fi
	CONTINUE_CHOICE=''
	#================ Pause before continuing ==================


	# Wireguard (Windows MSI installers)
	# https://download.wireguard.com/windows-client/
	WG_VER="$(curl -sS 'https://download.wireguard.com/windows-client/' | grep -oP "(x86|amd64|arm64)\-\d+\.\d+\.\d+" | cut -d '-' -f 2 | uniq)"
	if ! [ -e /opt/wireguard ]; then
		echo -e "${BLUE}[i]Downloading wireguard Windows installers...${RESET}"
		mkdir "$SETUPDIR"/wireguard
		cd "$SETUPDIR"/wireguard || exit

		curl -sSLO 'https://download.wireguard.com/windows-client/wireguard-arm64-'"$WG_VER"'.msi'
		sha256sum wireguard-arm64-"$WG_VER".msi

		curl -sSLO 'https://download.wireguard.com/windows-client/wireguard-amd64-'"$WG_VER"'.msi'
		sha256sum wireguard-amd64-"$WG_VER".msi

		curl -sSLO 'https://download.wireguard.com/windows-client/wireguard-x86-'"$WG_VER"'.msi'
		sha256sum wireguard-x86-"$WG_VER".msi
	fi

	#================ Pause before continuing ==================
	until [[ $CONTINUE_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Continue? [y/n]: " -e -i y CONTINUE_CHOICE
	done
	if [ "$CONTINUE_CHOICE" == 'n' ]; then
		echo "Check $SETUPDIR before running again. Quitting."
		exit 1
	fi
	CONTINUE_CHOICE=''
	#================ Pause before continuing ==================


	# Invoke-SocksProxy
	#https://github.com/BC-SECURITY/Invoke-SocksProxy
	if ! [ -e /opt/Invoke-SocksProxy ]; then
		echo -e "${BLUE}[i]Downloading Invoke-SocksProxy...${RESET}"
		cd "$SETUPDIR"/ || exit
		git clone 'https://github.com/BC-SECURITY/Invoke-SocksProxy.git'
	fi


	# Python3 installers for Windows
	PYTHON3_VER='3.10.4'
	if ! [ -e /opt/python3 ]; then
		echo -e "${BLUE}[i]Downloading python3 installers...${RESET}"
		mkdir "$SETUPDIR"/python3
		cd "$SETUPDIR"/python3 || exit
		curl -Lf 'https://keybase.io/stevedower/pgp_keys.asc?fingerprint=7ed10b6531d7c8e1bc296021fc624643487034e5' | gpg --import
		curl -sSLO 'https://www.python.org/ftp/python/'"$PYTHON3_VER"'/python-'"$PYTHON3_VER"'-amd64.exe'
		curl -sSLO 'https://www.python.org/ftp/python/'"$PYTHON3_VER"'/python-'"$PYTHON3_VER"'-amd64.exe.asc'
		curl -sSLO 'https://www.python.org/ftp/python/'"$PYTHON3_VER"'/python-'"$PYTHON3_VER"'.exe'
		curl -sSLO 'https://www.python.org/ftp/python/'"$PYTHON3_VER"'/python-'"$PYTHON3_VER"'.exe.asc'

		# 64-bit
		if (gpg --verify ./'python-'"$PYTHON3_VER"'-amd64.exe.asc' ./'python-'"$PYTHON3_VER"'-amd64.exe'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi

		# 32-bit
		if (gpg --verify ./'python-'"$PYTHON3_VER"'.exe.asc' ./'python-'"$PYTHON3_VER"'.exe'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
	fi

	#================ Pause before continuing ==================
	until [[ $CONTINUE_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Continue? [y/n]: " -e -i y CONTINUE_CHOICE
	done
	if [ "$CONTINUE_CHOICE" == 'n' ]; then
		echo "Check $SETUPDIR before running again. Quitting."
		exit 1
	fi
	#================ Pause before continuing ==================


	# Invoke-Obfuscation
	# https://github.com/danielbohannon/Invoke-Obfuscation/archive/master.zip
	if ! [ -e /opt/Invoke-Obfuscation ]; then
		echo -e "${BLUE}[i]Downloading Invoke-Obfuscation...${RESET}"
		mkdir "$SETUPDIR"/Invoke-Obfuscation
		cd "$SETUPDIR"/Invoke-Obfuscation || exit

		curl -sSLO 'https://github.com/danielbohannon/Invoke-Obfuscation/archive/f20e7f843edd0a3a7716736e9eddfa423395dd26.zip'
		mv f20e7f843edd0a3a7716736e9eddfa423395dd26.zip Invoke-Obfuscation.zip

		if (sha256sum ./Invoke-Obfuscation.zip | grep '24149efe341b4bfc216dea22ece4918abcbe0655d3d1f3c07d1965fac5b4478e'); then
			echo -e "${GREEN}[OK]${RESET}"
			unzip ./Invoke-Obfuscation.zip
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
	fi


	# Invoke-CradleCrafter
	# https://github.com/danielbohannon/Invoke-CradleCrafter
	if ! [ -e /opt/Invoke-CradleCrafter ]; then
		echo -e "${BLUE}[i]Downloading Invoke-CradleCrafter...${RESET}"
		mkdir "$SETUPDIR"/Invoke-CradleCrafter
		cd "$SETUPDIR"/Invoke-CradleCrafter || exit

		curl -sSLO 'https://github.com/danielbohannon/Invoke-CradleCrafter/archive/3ff8bacd5fb6aa14a0b757808437c9e230932379.zip'
		mv 3ff8bacd5fb6aa14a0b757808437c9e230932379.zip Invoke-CradleCrafter.zip

		if (sha256sum ./Invoke-CradleCrafter.zip | grep '7dee05c8509770a88ba3913ce4bc9cd5e94f446025d33095e000187f95e525b9'); then
			echo -e "${GREEN}[OK]${RESET}"
			unzip ./Invoke-CradleCrafter.zip
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
	fi


	# Posh-SecMod
	# https://github.com/darkoperator/Posh-SecMod
	if ! [ -e /opt/Posh-SecMod ]; then
		echo -e "${BLUE}[i]Downloading Posh-SecMod...${RESET}"
		mkdir "$SETUPDIR"/Posh-SecMod
		cd "$SETUPDIR"/Posh-SecMod || exit

		curl -sSLO 'https://github.com/darkoperator/Posh-SecMod/archive/a4b7f5039c98ed270e5d20c1081d44b5a387e3c2.zip'
		mv a4b7f5039c98ed270e5d20c1081d44b5a387e3c2.zip Posh-SecMod.zip

		if (sha256sum ./Posh-SecMod.zip | grep 'de4f328a07f0fe0185bfce663288ee2d303ffa12c845184cec0662208f5f7204'); then
			echo -e "${GREEN}[OK]${RESET}"
			unzip ./Invoke-CradleCrafter.zip
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
	fi

	#================ Pause before continuing ==================
	until [[ $CONTINUE_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Continue? [y/n]: " -e -i y CONTINUE_CHOICE
	done
	if [ "$CONTINUE_CHOICE" == 'n' ]; then
		echo "Check $SETUPDIR before running again. Quitting."
		exit 1
	fi
	CONTINUE_CHOICE=''
	#================ Pause before continuing ==================


	# TrevorC2
	# https://github.com/trustedsec/trevorc2
	if ! [ -e /opt/trevorc2 ]; then
		echo -e "${BLUE}[i]Downloading TrevorC2...${RESET}"
		cd "$SETUPDIR"/ || exit
		git clone 'https://github.com/trustedsec/trevorc2.git'
	fi

	# ProcMon for Linux
	# https://github.com/Sysinternals/ProcMon-for-Linux

	# Sysmon for Linux
	# https://github.com/Sysinternals/SysmonForLinux/blob/main/INSTALL.md
	if ! (command -v sysmon > /dev/null); then
		echo -e "${BLUE}[i]Installing sysmon...${RESET}"
		wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.asc.gpg
		sudo mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/
		wget -q https://packages.microsoft.com/config/debian/11/prod.list
		sudo mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
		sudo chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg
		sudo chown root:root /etc/apt/sources.list.d/microsoft-prod.list
		sudo apt-get update
		sudo apt-get install apt-transport-https
		sudo apt-get update
		sudo apt-get install sysmonforlinux

		# https://raw.githubusercontent.com/Sysinternals/SysmonForLinux/main/README.md

		if [ "$?" -ne '0' ]; then
			exit 1
		fi
	fi

	# trid
	# https://www.mark0.net/soft-trid-e.html
	# REMnux tool, similar to `file` command, with different definitions

	# ILSpy
	# https://github.com/icsharpcode/ILSpy
	# Similar to PeStudio

	# Die (Detect It Easy)
	# File signature and static analysis tool for Windows / macOS / Linux, similar to running `file`
	# https://github.com/horsicq/Detect-It-Easy
	# https://github.com/horsicq/DIE-engine/releases

	# traitor
	#curl -sSLO 'https://github.com/liamg/traitor/releases/download/v0.0.8/traitor-386'
	#curl -sSLO 'https://github.com/liamg/traitor/releases/download/v0.0.8/traitor-amd64'
	#curl -sSLO 'https://github.com/liamg/traitor/releases/download/v0.0.8/traitor-arm64'

# GraphQLmap can be installed with pipx
#	# GraphQLmap
#	if ! [ -e /opt/GraphQLmap ]; then
#		echo -e "${BLUE}[i]Downloading GraphQLmap...${RESET}"
#		cd "$SETUPDIR"/ || exit
#		git clone 'https://github.com/swisskyrepo/GraphQLmap.git'
#
#		source /home/kali/venv/bin/activate
#		cd ./GraphQLmap || exit
#		python3 ./setup.py install
#		if (graphqlmap -h); then
#			echo -e "${GREEN}[OK]${RESET}"
#		else
#			echo -e "${YELLOW}[i]Issue setting up GraphQLmap.${RESET}"
#		fi
#	fi

	# CVE-2021-4034 pwnkit
	# https://github.com/arthepsy/CVE-2021-4034
	# https://github.com/PwnFunction/CVE-2021-4034
	if ! [ -e /opt/pwnkit ]; then
		echo -e "${BLUE}[i]Downloading PwnKit CVE-2021-4034...${RESET}"
		cd "$SETUPDIR"/ || exit
		git clone 'https://github.com/PwnFunction/CVE-2021-4034.git'
	fi

	# Didier Stevens Suite
	# https://github.com/DidierStevens/DidierStevensSuite
	if ! [ -e /opt/DidierStevensSuite ]; then
		echo -e "${BLUE}[i]Didier Stevens Suite...${RESET}"
		cd "$SETUPDIR"/ || exit
		git clone 'https://github.com/DidierStevens/DidierStevensSuite.git'
	fi

	#================ Pause before continuing ==================
	until [[ $CONTINUE_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "Continue? [y/n]: " -e -i y CONTINUE_CHOICE
	done
	if [ "$CONTINUE_CHOICE" == 'n' ]; then
		echo "Check $SETUPDIR before running again. Quitting."
		exit 1
	fi
	CONTINUE_CHOICE=''
	#================ Pause before continuing ==================


	# pspy
	if ! [ -e /opt/pspy ]; then
		echo -e "${BLUE}[i]Downloading pspy...${RESET}"
		mkdir "$SETUPDIR"/pspy
		cd "$SETUPDIR"/pspy || exit

		curl -sSLO 'https://github.com/DominicBreuker/pspy/releases/download/v1.2.0/pspy64'
		if (sha256sum ./pspy64 | grep 'f7f14aa19295598717e4f3186a4002f94c54e28ec43994bd8de42caf79894bdb'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
		curl -sSLO 'https://github.com/DominicBreuker/pspy/releases/download/v1.2.0/pspy64s'
		if (sha256sum ./pspy64s | grep 'c769c23f8b225a2750768be9030b0d0f35778b7dff4359fa805f8be9acc6047f'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
		curl -sSLO 'https://github.com/DominicBreuker/pspy/releases/download/v1.2.0/pspy32'
		if (sha256sum ./pspy32 | grep '7cd8fd2386a30ebd1992cc595cc1513632eea4e7f92cdcaee8bcf29a3cff6258'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
		curl -sSLO 'https://github.com/DominicBreuker/pspy/releases/download/v1.2.0/pspy32s'
		if (sha256sum ./pspy32s | grep '0265a9d906801366210d62bef00aec389d872f4051308f47e42035062d972859'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
	fi

	# PEASS
	if ! [ -e /opt/PEASS ]; then
		echo -e "${BLUE}[i]Downloading PEASS...${RESET}"
		mkdir "$SETUPDIR"/PEASS
		cd "$SETUPDIR"/PEASS || exit

		curl -sSLO 'https://github.com/carlospolop/PEASS-ng/releases/download/20220511/winPEASx64.exe'
		if (sha256sum ./winPEASx64.exe | grep '3f27b4e6b2358e7ee3914fae37f87890cfef8e4f3c052f9ad10936168d2fd75f'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi

		curl -sSLO 'https://github.com/carlospolop/PEASS-ng/releases/download/20220511/winPEASx86.exe'
		if (sha256sum ./winPEASx86.exe | grep 'f9cec44b9bbd2f60b1e04cbf07d0261e29cb62545d405e7e512d802c32bcb682'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi

		curl -sSLO 'https://raw.githubusercontent.com/carlospolop/PEASS-ng/cc00bf89ab25fc7818aac2a3476539f24c26a720/winPEAS/winPEASbat/winPEAS.bat'
		if (sha256sum ./winPEAS.bat | grep '45b21e41e29c93100a02977c1f8679d6fc70a01c765f365b509271bebc7fbf6c'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi

		echo -e "${YELLOW}[i]${RESET}Converting line endings in winPEAS.bat..."
		unix2dos ./winPEAS.bat

		curl -sSLO 'https://raw.githubusercontent.com/carlospolop/PEASS-ng/23ec6e622c18744c8ad75e57a60f28f977896209/linPEAS/linpeas.sh'
		if (sha256sum ./linpeas.sh | grep 'dfc3784d2553b9221bdfcf5c839d8c38601d606d7f8f398db0405ec1e9968bf8'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
	fi

	# mimipenguin
	if ! [ -e /opt/mimipenguin ]; then
		echo -e "${BLUE}[i]Downloading mimipenguin...${RESET}"
		mkdir "$SETUPDIR"/mimipenguin
		cd "$SETUPDIR"/mimipenguin || exit
		curl -sSLO 'https://raw.githubusercontent.com/huntergregal/mimipenguin/3624a9b9cfe00db69181aa153f2813a08c929bb3/mimipenguin.sh'
		if (sha256sum ./mimipenguin.sh | grep '3acfe74cd2567e9cc60cb09bc4d0497b81161075510dd75ef8363f72c49e1789'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
		curl -sSLO 'https://raw.githubusercontent.com/huntergregal/mimipenguin/3624a9b9cfe00db69181aa153f2813a08c929bb3/mimipenguin.py'
		if (sha256sum ./mimipenguin.py | grep '79b478d9453cb18d2baf4387b65dc01b6a4f66a620fa6348fa8dbb8549a04a20'); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
	fi

	# Sysinternals
	if ! [ -e /opt/sysinternals ]; then
		# Binaries are signed by microsoft, review them with SigCheck64.exe and track them separately from this script
		echo -e "${BLUE}[i]Downloading the Sysinternals Suite...${RESET}"
		mkdir "$SETUPDIR"/sysinternals
		cd "$SETUPDIR"/sysinternals || exit
		curl -sSLO 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
		unzip ./SysinternalsSuite.zip && \
		rm ./SysinternalsSuite.zip
	fi

	# Plink
	if ! [ -e /opt/Putty ]; then
		echo -e "${BLUE}[i]Downloading plink binaries...${RESET}"
		mkdir "$SETUPDIR"/Putty
		cd "$SETUPDIR"/Putty || exit

		gpg --keyid-format long --keyserver hkps://keyserver.ubuntu.com:443 --recv-keys 'E273 94AC A3F9 D904 9522  E054 6289 A25F 4AE8 DA82'

		## x64
		curl -sSL 'https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe' > plink-x64.exe
		curl -sSL 'https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe.gpg' > plink-x64.exe.gpg
		## ARM
		curl -sSL 'https://the.earth.li/~sgtatham/putty/latest/wa64/plink.exe' > plink-a64.exe
		curl -sSL 'https://the.earth.li/~sgtatham/putty/latest/wa64/plink.exe.gpg' > plink-a64.exe.gpg
		## x86
		curl -sSL 'https://the.earth.li/~sgtatham/putty/latest/w32/plink.exe' > plink-x86.exe
		curl -sSL 'https://the.earth.li/~sgtatham/putty/latest/w32/plink.exe.gpg' > plink-x86.exe.gpg

		## Check signatures
		echo -e "${BLUE}[i]Checking plink-x64...${RESET}"
		if (gpg --verify --keyid-format long plink-x64.exe.gpg plink-x64.exe); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature. Quitting.${RESET}"
			exit 1
		fi
		echo ""

		echo -e "${BLUE}[i]Checking plink-a64...${RESET}"
		if (gpg --verify --keyid-format long plink-a64.exe.gpg plink-a64.exe); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature. Quitting.${RESET}"
			exit 1
		fi
		echo ""

		echo -e "${BLUE}[i]Checking plink-x86...${RESET}"
		if (gpg --verify --keyid-format long plink-x86.exe.gpg plink-x86.exe); then
			echo -e "${GREEN}[OK]${RESET}"
		else
			echo -e "${RED}[i]Bad signature. Quitting.${RESET}"
			exit 1
		fi
		echo ""
	fi

	# Adjust permissions
	find "$SETUPDIR" -type f -print0 | xargs -0 chmod 640
	find "$SETUPDIR" -type d -print0 | xargs -0 chmod 750

	sudo chown -R root:"$USERNAME" "$SETUPDIR"/*

	sudo mv "$SETUPDIR"/* -t /opt

	echo -e "${BLUE}[i]Done.${RESET}"

}

function CleanUp() {

	if [ -d /tmp/tools ]; then
		sudo rm -rf /tmp/tools
	fi

}

MakeTemp
InstallAptPackages
AddAliases
#InstallSnaps
InstallPypiPackages
#InstallGems
#InstallGo
InstallExternalTools
CleanUp

exit
