#!/bin/bash

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

UID1000="$(grep '1000' /etc/passwd | cut -d ':' -f 1)"

# Installation and setup of general security tools
# to do: use git + chmod -R $USERNAME:$USERNAME to make /opt directories writable and updatable, and also return them read-only permissions by root and $USERNAME after updating.

if [ "${EUID}" -ne 1000 ]; then
	echo "You need to run this script as $UID1000"
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
MakeTemp


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
	crackmapexec \
	crunch \
	curl \
	dirb \
	dirbuster \
	dos2unix \
	dsniff \
	enum4linux \
	exploitdb \
	feroxbuster \
	gobuster \
	hashcat \
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
	nmap \
	onesixtyone \
	oscanner \
	p7zip \
	p7zip-rar \
	pdfid \
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
	smbclient \
	smbmap \
	smtp-user-enum \
	snmp \
	snmpcheck \
	sqlmap \
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
	
	# To do: rewrite this to handle missing or renamed (updated) packages

	#smb-nat \
	#golang-1.17 \
	#gvncviewer \
	#exploitdb-bin-sploits \
	#kazam \
#	svwar \ does not exist -> could be sipvicious/kali-rolling 0.3.3-2 all

	sleep 3

}
InstallAptPackages

function AddAliases() {

	# Two wireshark windows are useful for monitoring two network interfaces in real time
	if ! (grep "alias dualshark='wireshark&;wireshark&'" "$HOME"/.zshrc); then
		echo -e "${BLUE}[i]${RESET}Adding custom aliases..."
		{
		echo ""
		echo "# alias for visibility while scanning"
		echo "alias dualshark='wireshark&;wireshark&'"
		} >> "$HOME"/.zshrc
	fi

}
AddAliases

function InstallSnaps() {
	# /etc/profile.d/apps-bin-path.sh SHOULD add snap bins to PATH, check for snaps in PATH anyway:
	if ! (echo $PATH | grep -q '/snap/bin'); then
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

	if ! (command -v snap > /dev/null); then
		echo -e "${BLUE}[i]Installing snapd...${RESET}"
		sudo apt install -y snapd
		sleep 2
		echo -e "${BLUE}[i]Installing snap packages...${RESET}"
		sudo snap install chromium
		sudo snap install libreoffice
		sudo snap install vlc
	else
		echo -e "${BLUE}[i]Refreshing snaps...${RESET}"
		sudo snap refresh
	fi

}
InstallSnaps

function InstallPypiPackages() {

	echo -e "${BLUE}[i]Installing PyPi tools...${RESET}"

# To do: pipenv

# pipx
	python3 -m pip install --user pipx
	python3 -m pipx ensurepath

#	pipx install git+https://github.com/Tib3rius/AutoRecon.git

# pip
	cd "$HOME" || exit

	if ! [ -e "$HOME"/venv/bin/activate ]; then
		mkdir "$HOME"/venv
		python3 -m venv ~/venv
	fi

	source "$HOME"/venv/bin/activate

	python3 -m pip install mitm6
	python3 -m pip install --pre scapy[basic]
	#python3 -m pip install ldapdomaindump
	#python3 -m pip install matplotlib
	#python3 -m pip install cryptography
	python3 -m pip install paramiko
	#python3 -m pip install pyx
	python3 -m pip install beautifulsoup4 lxml requests
	#python3 -m pip install --upgrade xlrd

	deactivate

	cd "$HOME" || exit

}
InstallPypiPackages


function InstallGems() {

	echo -e "${BLUE}[i]Installing gems...${RESET}"

	gem install evil-winrm --user-install

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

}
InstallGems

function InstallGo() {

	echo -e "${BLUE}[i]Installing golang...${RESET}"
	sudo apt -y install golang-1.17

	echo -e "${BLUE}[i]Adding go to PATH...${RESET}"

	{
	echo ''
	echo '# set PATH so it includes go installation if it exists'
	echo 'if [ -d "/usr/local/go" ] ; then'
	echo '    PATH="$PATH:/usr/local/go/bin"'
	echo 'fi' 
	} > "$SETUPDIR"/go-path.sh

	sudo cp "$SETUPDIR"/go-path.sh /etc/profile.d/go-path.sh

	source /etc/profile.d/go-path.sh

	# Don't want to always script this, give user the option
	echo -e "${YELLOW}[i]Use 'sudo visudo' to add '/usr/local/go/bin:' to the 'secure_path=...' variable${RESET}"

	go --version
	sleep 2

}
InstallGo

function InstallExternalTools() {

	cd "$SETUPDIR" || exit

	# Wordlists - download these individually for quick reference
	if ! [ -e /opt/wordlists ]; then
		echo -e "${BLUE}[i]Downloading wordlists...${RESET}"
		mkdir "$SETUPDIR"/wordlists
		cd "$SETUPDIR"/wordlists || exit

		# Top Usernames (shortlist)
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/top-usernames-shortlist.txt'

		# Common Passwords (Top 10000)
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/10-million-password-list-top-10000.txt'

		# Single Names ~10k
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/Names/names.txt'

		# Common Web Content
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt'

		# Web Content (default wordlist for Feroxbuster)
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-medium-directories.txt'

		# SNMP Community Strings
		curl -sSLO 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/SNMP/snmp-onesixtyone.txt'

		find "$SETUPDIR"/wordlists -type f -print0 | xargs -0 sudo chmod 640
		sudo mv "$SETUPDIR"/wordlists -t /opt

		echo -e "${BLUE}[i]Done.${RESET}"
	fi

	# SecLists
	if ! [ -e /opt/wordlists/SecLists ]; then
		cd "$SETUPDIR"/ || exit
		echo -e "${BLUE}[i]Downloading SecLists...${RESET}"
		git clone --depth 1 'https://github.com/danielmiessler/SecLists.git'
		find "$SETUPDIR"/SecLists -type f -print0 | xargs -0 chmod 640
		find "$SETUPDIR"/SecLists -type d -print0 | xargs -0 chmod 750
		sudo chown -R root:"$UID1000" "$SETUPDIR"/SecLists
		sudo mv "$SETUPDIR"/SecLists -t /opt/wordlists/ && \
		sudo ln -s /opt/wordlists/SecLists /usr/share/seclists
		echo -e "${BLUE}[i]Done.${RESET}"
	fi

	# Statistically Likely Usernames
	if ! [ -e /opt/wordlists/statistically-likely-usernames ]; then
		echo -e "${BLUE}[i]Downloading Statistically Likely Usernames...${RESET}"
		cd "$SETUPDIR"/ || exit
		git clone 'https://github.com/insidetrust/statistically-likely-usernames.git'
		find "$SETUPDIR"/statistically-likely-usernames -type f -print0 | xargs -0 chmod 640
		find "$SETUPDIR"/statistically-likely-usernames -type d -print0 | xargs -0 chmod 750
		sudo chown -R root:"$UID1000" "$SETUPDIR"/statistically-likely-usernames
		sudo mv "$SETUPDIR"/statistically-likely-usernames -t /opt/wordlists/
		echo -e "${BLUE}[i]Done.${RESET}"
	fi


	# To do:
	# trid
	#REMnux tool, similar to `file` command, with different definitions

	# ILSpy
	#<https://github.com/icsharpcode/ILSpy>
	#Similar to PeStudio

	# de4dot
	#<https://github.com/0xd4d/de4dot>
	#deobfuscates and unpacks symbols in .NET

	# Die (Detect It Easy)
	#File signature and static analysis tool for Windows / macOS / Linux, similar to running `file`
	#<https://github.com/horsicq/Detect-It-Easy>
	#<https://github.com/horsicq/DIE-engine/releases>

	# traitor
	#curl -sSLO 'https://github.com/liamg/traitor/releases/download/v0.0.8/traitor-386'
	#curl -sSLO 'https://github.com/liamg/traitor/releases/download/v0.0.8/traitor-amd64'
	#curl -sSLO 'https://github.com/liamg/traitor/releases/download/v0.0.8/traitor-arm64'


	# oledump
	if ! [ -e /opt/oledump ]; then
		echo -e "${BLUE}[i]Downloading oledump...${RESET}"
		mkdir "$SETUPDIR"/oledump
		cd "$SETUPDIR"/oledump || exit
		curl -LfO 'https://didierstevens.com/files/software/oledump_V0_0_60.zip'
		if (sha256sum ./oledump_V0_0_60.zip | grep 'd847e499cb84b034e08bcddc61addada39b90a5fa2e1aba0756a05039c0d8ba2'); then
			echo -e "${GREEN}[OK]${RESET}"
			sleep 2
			unzip ./oledump_V0_0_60.zip && \
			rm ./oledump_V0_0_60.zip
		else
			echo -e "${RED}[i]Bad signature.${RESET}"
		fi
		echo -e "${BLUE}[i]Done.${RESET}"
	fi


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
		echo -e "${BLUE}[i]Done.${RESET}"
	fi

	# PEASS
	if ! [ -e /opt/PEASS ]; then
		echo -e "${BLUE}[i]Downloading PEASS...${RESET}"
		mkdir "$SETUPDIR"/PEASS
		cd "$SETUPDIR"/PEASS || exit
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
		echo -e "${BLUE}[i]Done.${RESET}"
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
		echo -e "${BLUE}[i]Done.${RESET}"
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
		echo -e "${BLUE}[i]Done.${RESET}"
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

		echo -e "${BLUE}[i]Done.${RESET}"
	fi

	find "$SETUPDIR" -type f -print0 | xargs -0 chmod 640
	find "$SETUPDIR" -type d -print0 | xargs -0 chmod 750
	sudo chown -R root:"$UID1000" "$SETUPDIR"

	sudo mv "$SETUPDIR"/* -t /opt

}
InstallExternalTools

function CleanUp() {

	if [ -d /tmp/tools ]; then
		sudo rm -rf /tmp/tools
	fi

}
CleanUp

exit
