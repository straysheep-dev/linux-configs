#!/bin/bash


# MIT License 2024 straysheep-dev

# Install all necessary tools via apt
# Enables ufw (allow-outbound block-inbound block-routed)
# Downloads the SNMP MIB data and configures /etc/snmp/snmp.conf
# Downloads individual files with no GitHub release
# Downloads the latest releases of external tools from GitHub
# Code taken from BishopFox's Sliver Installer Script: https://github.com/BishopFox/sliver/blob/master/docs/install

# The following tools still need compiled manually:
# Rubeus
# SharpDPAPI / SharpChrome
# Seatbelt
# Sharpmad
# KrbRelay
# UACME

# You will also need to reinstall any custom scripts and utilites:
# scan-parser.sh
# html-parser.py
# network-triage.sh
# /opt/scripts/* utilities

function InstallAPTPackages() {

    # EXTRA TOOLS
    # -----------
    # beef-xss
    # de4dot
    # nishang
    # ssdeep

    APT_LIST='apparmor-profiles
    apparmor-profiles-extra
    apparmor-utils
    bettercap
    binwalk
    bloodhound
    bloodhound.py
    braa
    burpsuite
    cadaver
    cifs-utils
    code-oss
    crackmapexec
    crunch
    curl
    davtest
    dirb
    dirbuster
    dnscat2
    dos2unix
    enum4linux
    evil-winrm
    exploitdb
    feroxbuster
    gdb
    ghidra
    gobuster
    hashcat
    hashid
    hash-identifier
    hexedit
    hping3
    hydra
    impacket-scripts
    iodine
    john
    jq
    krb5-user
    libimage-exiftool-perl
    libssl-dev
    mariadb-client-core
    masscan
    mimikatz
    mingw-w64
    ncat
    ncrack
    neo4j
    nikto
    nmap
    onesixtyone
    oscanner
    p7zip
    p7zip-rar
    pdfid
    peass
    pipx
    poppler-utils
    powercat
    powershell
    powershell-empire
    powersploit
    proxychains4
    python3-pip
    python3-pypykatz
    python3-pywerview
    python3-scapy
    python3-venv
    rdesktop
    redis-tools
    ridenum
    rsmangler
    screen
    seclists
    smbclient
    smbmap
    smtp-user-enum
    snmp
    snmp-mibs-downloader
    snmpcheck
    sqlmap
    ssh-audit
    sshuttle
    sslscan
    thc-ipv6
    thunderbird
    tmux
    tshark
    ufw
    webshells
    wfuzz
    whatweb
    windows-binaries
    wireshark
    xxd
    zaproxy
    '

    sudo apt update; sudo apt full-upgrade -y
    sudo apt install -y $APT_LIST
    sudo apt autoremove --purge -y

}


function ConfigureAPTPackages() {

    # Enable the firewall
    echo "[*]Configuring UFW..."
    sudo ufw enable

    # Resetting OpenSSH Server Host Keys
    echo "[*]Resetting OpenSSH Server Host Keys..."
    sudo rm -rf /etc/ssh/*host*
    sudo ssh-keygen -A

    # Download the mib data for SNMP enumeration
    echo "[*]Downloading MIBs..."
    sudo download-mibs
    sudo sed -i 's/^mibs :$/#mibs :/' /etc/snmp/snmp.conf

    # Configure proxychains timeout for scanning optimization
    echo "[*]Configuring proxychains4.conf..."
    sudo sed -i -E 's/^#?tcp_read_time_out.*$/tcp_read_time_out 5000/' /etc/proxychains4.conf
    sudo sed -i -E 's/^#?tcp_connect_time_out.*$/tcp_connect_time_out 800/' /etc/proxychains4.conf

    # Start neo4j
    echo "[*]Starting neo4j..."
    sudo neo4j start

}


function DownloadFiles() {

    FILE_LIST='https://live.sysinternals.com/procdump64.exe
    https://live.sysinternals.com/PsExec64.exe
    https://live.sysinternals.com/strings64.exe
    https://live.sysinternals.com/tcpview64.exe
    https://raw.githubusercontent.com/NotSoSecure/password_cracking_rules/master/OneRuleToRuleThemAll.rule
    https://raw.githubusercontent.com/CompassSecurity/BloodHoundQueries/master/BloodHound_Custom_Queries/customqueries.json
    https://raw.githubusercontent.com/Kevin-Robertson/Powermad/master/Powermad.ps1
    https://raw.githubusercontent.com/NetSPI/PowerUpSQL/master/PowerUpSQL.ps1
    '

    for URL in $FILE_LIST
    do
        FILE=$(basename "$URL")
        echo "[*]Downloading $FILE..."
        curl -sS -L "$URL" --output ~/Downloads/"$FILE"
    done

}


function DownloadGitHubReleases() {

    AUTHOR_REPO_LIST='projectdiscovery/naabu
    jpillora/chisel
    Pennyw0rth/NetExec
    DominicBreuker/pspy
    itm4n/PrintSpoofer
    antonioCoco/JuicyPotatoNG
    ropnop/kerbrute'

    IGNORE_LIST='(mac|darwin|arm|mips|ia32|ppc|s390x)'

    for AUTHOR_REPO in $AUTHOR_REPO_LIST
    do
        echo "[>] Creating ~/Downloads/$AUTHOR_REPO..."
        mkdir -p ~/Downloads/"$AUTHOR_REPO" > /dev/null
        ARTIFACTS=$(curl -s https://api.github.com/repos/"$AUTHOR_REPO"/releases/latest | awk -F '"' '/browser_download_url/{print $4}')
        for URL in $ARTIFACTS
        do
            ARCHIVE=$(basename "$URL")
            if [[ ! "$ARCHIVE" =~ $IGNORE_LIST ]]; then
                echo "[*]Downloading $ARCHIVE..."
                curl --silent -L "$URL" --output ~/Downloads/"$AUTHOR_REPO"/"$ARCHIVE"
            fi
        done
    done

}

function DownloadGitHubProjects() {

    PROJECT_LIST='https://github.com/insidetrust/statistically-likely-usernames
    https://github.com/straysheep-dev/linux-configs
    '

    for PROJECT in $PROJECT_LIST
    do
        echo "[*]Cloning $PROJECT..."
        git clone "$PROJECT"
    done

}


function InstallPipTools() {

    pipx install wsgidav

}

InstallAPTPackages
ConfigureAPTPackages
DownloadFiles
DownloadGitHubReleases
DownloadGitHubProjects
InstallPipTools

echo "[i]Done."