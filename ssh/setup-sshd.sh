#!/bin/bash

# Setup and configure an openssh server.
# This script takes functions from https://github.com/straysheep-dev/setup-ubuntu
# Currently the MFA function only applies to desktop GUI logins, and not ssh logins - this will need revised.
# Tested on Ubuntu 20.04 and 22.04.

# Thanks to the following projects for code, ideas, and guidance:
# https://github.com/Disassembler0/Win10-Initial-Setup-Script
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/wireguard-install
# https://github.com/drduh/YubiKey-Guide
# https://github.com/drduh/config
# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
# https://github.com/ComplianceAsCode/content



RED="\033[01;31m"      # Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings
BLUE="\033[01;34m"     # Success
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

#PUB_IPV4=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
#PUB_IPV6=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)
PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
GTWY="$(ip route | grep 'default' | cut -d ' ' -f3)"

VM='false'
HW='false'
VPS='false'

function isRoot() {
	if [ "${EUID}" -eq 0 ]; then
		echo "You need to run this script as a normal user"
		exit 1
	fi
}

isRoot


function setSSH() {

	SSHD_CONF='/etc/ssh/sshd_config'

	echo "======================================================================"
	if ! (command -v sshd > /dev/null); then
		echo ""
		echo "Install OpenSSH server?"
		echo ""
		until [[ $SSHD_INSTALL_CHOICE =~ ^(y|n)$ ]]; do
			read -rp "[y/n]: " SSHD_INSTALL_CHOICE
		done
		if [[ $SSHD_INSTALL_CHOICE == "y" ]]; then
			if (command -v apt > /dev/null); then
				sudo apt install -y openssh-server
			elif (command -v dnf > /dev/null); then
				sudo dnf install -y openssh-server
			fi
		fi
	elif ! (systemctl is-active sshd > /dev/null); then
		echo ""
		echo "Start and enable OpenSSH server?"
		echo ""
		until [[ $SSHD_START_CHOICE =~ ^(y|n)$ ]]; do
			read -rp "[y/n]: " SSHD_START_CHOICE
		done
		if [[ $SSHD_START_CHOICE == "y" ]]; then

			sudo systemctl start sshd
			sudo systemctl enable sshd
			echo -e "${BLUE}[+]${RESET}Starting and enabling sshd.service..."
		fi
	fi

	if [ -e "$SSHD_CONF" ]; then
		echo -e "${BLUE}[i]${RESET}Regenerating server host keys..."
		sudo rm /etc/ssh/ssh_host_*
		sudo ssh-keygen -A

		echo -e "${BLUE}[i]${RESET}Updating SSHD config..."
		if ! [ -e /etc/ssh/sshd_config.bkup ]; then
			sudo cp /etc/ssh/sshd_config -n /etc/ssh/sshd_config.bkup
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
		# xccdf_org.ssgproject.content_group_ssh_server

		if ! (grep -Eq "^PasswordAuthentication no$" "$SSHD_CONF"); then
			if (grep -Eq "^.*PasswordAuthentication.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*PasswordAuthentication.*$/PasswordAuthentication no/g' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: PasswordAuthentication no"
			else
				echo "PasswordAuthentication no" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: PasswordAuthentication no"
			fi
		fi

		if ! (grep -Eq "^PermitRootLogin no$" "$SSHD_CONF"); then
			if (grep -Eq "^.*PermitRootLogin.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*PermitRootLogin.*$/PermitRootLogin no/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: PermitRootLogin no"
			else
				echo "PermitRootLogin no" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: PermitRootLogin no"
			fi
		fi

		# This no longer appears as an option, only referenced in /etc/rkhunter.conf
#		if ! (grep -Eq "^Protocol 2$" "$SSHD_CONF"); then
#			if (grep -Eq "^.*Protocol.*$" "$SSHD_CONF"); then
#				sudo sed -i 's/^.*Protocol.*$/&\nProtocol 2/' "$SSHD_CONF"
#				echo -e "${GREEN}[+]${RESET}Prohibiting SSHv1 protocol."
#			else
#				echo "Protocol 2" | sudo tee -a "$SSHD_CONF"
#				echo -e "${GREEN}[+]${RESET}Prohibiting SSHv1 protocol."
#			fi
#		fi

		if ! (grep -Eq "^PermitEmptyPasswords no$" "$SSHD_CONF"); then
			if (grep -Eq "^.*PermitEmptyPasswords.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*PermitEmptyPasswords.*$/PermitEmptyPasswords no/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: PermitEmptyPasswords no"
			else
				echo "PermitEmptyPasswords no" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: PermitEmptyPasswords no"
			fi
		fi

		if ! (grep -Eq "^AllowAgentForwarding no$" "$SSHD_CONF"); then
			if (grep -Eq "^.*AllowAgentForwarding.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*AllowAgentForwarding.*$/AllowAgentForwarding no/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: AllowAgentForwarding no"
			else
				echo "AllowAgentForwarding no" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: AllowAgentForwarding no"
			fi
		fi

		# 600=10 minutes
		if ! (grep -Eq "^ClientAliveInterval 300$" "$SSHD_CONF"); then
			if (grep -Eq "^.*ClientAliveInterval.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*ClientAliveInterval.*$/ClientAliveInterval 300/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: ClientAliveInterval 300"
			else
				echo "ClientAliveInterval 300" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: ClientAliveInterval 300"
			fi
		fi

		# set 0 for ClientAliveInterval to be exact
		if ! (grep -Eq "^ClientAliveCountMax 0$" "$SSHD_CONF"); then
			if ( grep -Eq "^.*ClientAliveCountMax.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*ClientAliveCountMax.*$/ClientAliveCountMax 0/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: ClientAliveCountMax 0"
			else
				echo "ClientAliveCountMax 0" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: ClientAliveCountMax 0"
			fi
		fi


		# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
		# xccdf_org.ssgproject.content_rule_disable_host_auth
		if ! (grep -Eq "^HostbasedAuthentication no$" "$SSHD_CONF"); then
			if (grep -Eq "^.*HostbasedAuthentication.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*HostbasedAuthentication.*$/HostbasedAuthentication no/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: HostbasedAuthentication no"
			else
				echo "HostbasedAuthentication no" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: HostbasedAuthentication no"
			fi
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
		# xccdf_org.ssgproject.content_rule_sshd_disable_rhosts
		if ! (grep -Eq "^IgnoreRhosts yes$" "$SSHD_CONF"); then
			if (grep -Eq "^.*IgnoreRhosts.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*IgnoreRhosts.*$/IgnoreRhosts yes/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: IgnoreRhosts yes"
			else
				echo "IgnoreRhosts yes" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: IgnoreRhosts yes"
			fi
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
		# xccdf_org.ssgproject.content_rule_sshd_do_not_permit_user_env
		if ! (grep -Eq "^PermitUserEnvironment no$" "$SSHD_CONF"); then
			if (grep -Eq "^.*PermitUserEnvironment.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*PermitUserEnvironment.*$/PermitUserEnvironment no/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: PermitUserEnvironment no"
			else
				echo "PermitUserEnvironment no" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: PermitUserEnvironment no"
			fi
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
		# xccdf_org.ssgproject.content_rule_sshd_set_loglevel_info
		if ! (grep -Eq "^LogLevel INFO$" "$SSHD_CONF"); then
			if (grep -Eq "^.*LogLevel INFO.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*LogLevel INFO.*$/LogLevel INFO/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: LogLevel INFO"
			else
				echo "LogLevel INFO" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: LogLevel INFO"
			fi
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
		# xccdf_org.ssgproject.content_rule_sshd_set_max_auth_tries
		if ! (grep -Eq "^MaxAuthTries 4$" "$SSHD_CONF"); then
			if (grep -Eq "^.*MaxAuthTries.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*MaxAuthTries.*$/MaxAuthTries 4/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: MaxAuthTries 4"
			else
				echo "MaxAuthTries 4" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: MaxAuthTries 4"
			fi
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
		# xccdf_org.ssgproject.content_rule_sshd_disable_x11_forwarding
		if ! (grep -Eq "^X11Forwarding no$" "$SSHD_CONF"); then
			if ( grep -Eq "^.*X11Forwarding.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*X11Forwarding.*$/X11Forwarding no/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: X11Forwarding no"
			else
				echo "X11Forwarding no" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: X11Forwarding no"
			fi
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
		# xccdf_org.ssgproject.content_rule_sshd_use_approved_ciphers_ordered_stig
		if ! (grep -Eq "^Ciphers aes256-ctr,aes192-ctr,aes128-ctr$" "$SSHD_CONF"); then
			if ( grep -Eq "^(#Ciphers|Ciphers).*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*Ciphers.*$/Ciphers aes256-ctr,aes192-ctr,aes128-ctr/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: Ciphers aes256-ctr,aes192-ctr,aes128-ctr"
			else
				echo "Ciphers aes256-ctr,aes192-ctr,aes128-ctr" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: Ciphers aes256-ctr,aes192-ctr,aes128-ctr"
			fi
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
		# xccdf_org.ssgproject.content_rule_sshd_use_approved_macs_ordered_stig
		if ! (grep -Eq "^MACs hmac-sha2-512,hmac-sha2-256$" "$SSHD_CONF"); then
			if ( grep -Eq "^(MACs|#MACs).*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*MACs.*$/MACs hmac-sha2-512,hmac-sha2-256/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: MACs hmac-sha2-512,hmac-sha2-256"
			else
				echo "MACs hmac-sha2-512,hmac-sha2-256" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: MACs hmac-sha2-512,hmac-sha2-256"
			fi
		fi

		# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
		# xccdf_org.ssgproject.content_rule_sshd_x11_use_localhost
		if ! (grep -Eq "^X11UseLocalhost yes$" "$SSHD_CONF"); then
			if (grep -Eq ".*X11UseLocalhost.*$" "$SSHD_CONF"); then
				sudo sed -i 's/^.*X11UseLocalhost.*$/X11UseLocalhost yes/' "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: X11UseLocalhost yes"
			else
				echo "X11UseLocalhost yes" | sudo tee -a "$SSHD_CONF"
				echo -e "${GREEN}[+]${RESET}Setting: X11UseLocalhost yes"
			fi
		fi

		echo -e "${BLUE}[i]${RESET}What port do you want SSH to listen to?"
		echo "   1) Default: 22"
		echo "   2) Custom"
		echo "   3) Random [49152-65535]"
		until [[ $PORT_CHOICE =~ ^[1-3]$ ]]; do
			read -rp "[i]Port choice [1-3]: " -e -i 1 PORT_CHOICE
		done
		case $PORT_CHOICE in
		1)
			PORT="22"
			;;
		2)
			until [[ $PORT =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; do
				read -rp "[i]Custom port [1-65535]: " -e -i 22 PORT
			done
			;;
		3)
			# Generate random number within private ports range
			PORT=$(shuf -i49152-65535 -n1)
			echo -e "${GREEN}[i]${RESET}Random Port: ${BOLD}$PORT${RESET}"
			;;
		esac

		sudo sed -i 's/.*Port .*$/Port '"${PORT}"'/' "$SSHD_CONF"

		echo ""
		if (command -v iptables > /dev/null); then
			echo "iptables are available, use ip/ip6tables?"
			if (command -v ufw > /dev/null); then
				echo "(otherwise, ufw will be used)"
			elif (command -v firewall-cmd > /dev/null); then
				echo "(otherwise, firewall-cmd will be used)"
			fi
			echo ""
			until [[ $IPTABLES_CHOICE =~ ^(y|n)$ ]]; do
				read -rp "[y/n]: " IPTABLES_CHOICE
			done
			if [[ $IPTABLES_CHOICE == "y" ]]; then
				sudo iptables -A INPUT -i "$PUB_NIC" -p tcp -m tcp --dport "$PORT" -j ACCEPT
				sudo ip6tables -A INPUT -i "$PUB_NIC" -p tcp -m tcp --dport "$PORT" -j ACCEPT
			elif [[ $IPTABLES_CHOICE == "n" ]]; then
				if (command -v ufw > /dev/null); then
					sudo ufw allow in on "$PUB_NIC" to any proto tcp port "$PORT" comment 'ssh'
					echo -e "${GREEN}[+]${RESET}Added ufw rules for SSH port ${PORT}."
				elif (command -v firewall-cmd > /dev/null); then
					sudo firewall-cmd --add-port="$SSH_PORT"/tcp
					echo -e "${GREEN}[+]${RESET}Added firewall-cmd rules for SSH port ${PORT}."
				fi
			fi
		fi

		echo ""
		echo "The current connection will remain established until exiting."
		echo "Confirm you can login via ssh from another terminal session"
		echo "after this script completes, and before exiting this current"
		echo "session."
		echo ""
		echo "Restart sshd.service now?"
		echo ""
		until [[ $SSHD_RESTART_CHOICE =~ ^(y|n)$ ]]; do
			read -rp "[y/n]: " SSHD_RESTART_CHOICE
		done
		if [[ $SSHD_RESTART_CHOICE == "y" ]]; then

			sudo systemctl restart sshd.service
			echo -e "${BLUE}[+]${RESET}Restarting sshd.service..."
		fi

		echo -e "${RED}"'[!]'"${RESET}${BOLD}Be sure to review all firewall rules before ending this session.${RESET}"
		sleep 3
	fi
}

function setMFA() {

	# https://www.raspberrypi.org/blog/setting-up-two-factor-authentication-on-your-raspberry-pi/
	# https://github.com/0ptsec/optsecdemo

	SSHD_CONF='/etc/ssh/sshd_config'
	PAM_LOGIN='/etc/pam.d/login'
	PAM_GDM='/etc/pam.d/gdm-password'
	PAM_SSHD='/etc/pam.d/sshd'

	echo -e "${BLUE}[?]Configure libpam-google-authenticator for MFA login?${RESET}"
	if [ -e "$HOME"/.google_authenticator ]; then
		echo -e "${YELLOW}[i]${RESET}A $HOME/.google_authenticator already exists."
	fi
	echo ""
	until [[ $MFA_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "[y/n]: " MFA_CHOICE
	done
	if [[ $MFA_CHOICE == "y" ]]; then

		# Install libpam-google-authenticator if it's missing
		if ! (command -v google-authenticator > /dev/null); then
			sudo apt install -y libpam-google-authenticator
		fi

		# Check if this machine is running an OpenSSH server
		if [ -e "$SSHD_CONF" ]; then
	                if ! (grep -Eq "^ChallengeResponseAuthentication = yes$" "$SSHD_CONF"); then
	                        if (grep -Eq "^.*ChallengeResponseAuthentication.*$" "$SSHD_CONF"); then
	                                sudo sed -i 's/^.*ChallengeResponseAuthentication.*$/ChallengeResponseAuthentication = yes/' "$SSHD_CONF"
	                                echo -e "${GREEN}[+]${RESET}Setting: ChallengeResponseAuthentication = yes"
	                        else
	                                echo "ChallengeResponseAuthentication = yes" | sudo tee -a "$SSHD_CONF"
	                                echo -e "${GREEN}[+]${RESET}Setting: ChallengeResponseAuthentication = yes"
	                        fi
	                fi
	                if ! (grep -Eq "^auth required pam_google_authenticator.so no_increment_hotp nullok$" "$PAM_SSHD"); then
				echo '# libpam-google-authenticator 2fa
auth required pam_google_authenticator.so no_increment_hotp nullok' | sudo tee -a "$PAM_SSHD"
			fi

			sudo systemctl restart sshd
		fi

		# If this isn't a headless server, add MFA to desktop login as well.
		if ! [[ $VPS == 'true' ]]; then
			if ! (grep -Eq "^auth required pam_google_authenticator.so no_increment_hotp nullok$" "$PAM_LOGIN"); then
				echo '# libpam-google-authenticator 2fa
auth required pam_google_authenticator.so no_increment_hotp nullok' | sudo tee -a "$PAM_LOGIN"
		fi
			if ! (grep -Eq "^auth required pam_google_authenticator.so no_increment_hotp nullok$" "$PAM_GDM"); then
				echo '# libpam-google-authenticator 2fa
auth required pam_google_authenticator.so no_increment_hotp nullok' | sudo tee -a "$PAM_GDM"
			fi
		fi

		google-authenticator

	fi
}

# Command-Line-Arguments
function manageMenu() {
	echo ""
	echo "sshd server management menu"
	echo ""
	echo "   1) Setup openssh-server"
	echo "   2) Configure MFA logins"
	echo "   3) Exit"
	until [[ $MENU_OPTION =~ ^[1-3]$ ]]; do
		read -rp "Select an option [1-4]: " MENU_OPTION
	done

	case $MENU_OPTION in
	1)
		setSSH
		;;
	2)
		setMFA
		;;
	3)
		exit 0
		;;
	esac
}

manageMenu
