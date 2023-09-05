#!/bin/bash

# BSD-3 License
# Copyright (c) 2023, straysheep-dev
# Copyright (c) 2012-2017, Red Hat, Inc.

# Thanks to the following projects for code, ideas, and guidance:
# https://static.open-scap.org/ssg-guides/ssg-ubuntu2004-guide-stig.html
# https://github.com/ComplianceAsCode/content
# https://github.com/ComplianceAsCode/content/blob/master/LICENSE
# https://github.com/g0tmi1k/OS-Scripts
# https://github.com/angristan/wireguard-install

RED="\033[01;31m"      # Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings
BLUE="\033[01;34m"     # Success
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

USERNAME="$(grep "$EUID" /etc/passwd | cut -d ':' -f 1)"

function CheckKernel() {
	
	echo -e "${BLUE}[i]${RESET}Checking kernel parameters..."

	# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-standard.html

	# /etc/sysctl.d/README.sysctl
	# After making any changes, please run "service procps reload" (or, from
	# a Debian package maintainer script "deb-systemd-invoke restart procps.service").

	# xccdf_org.ssgproject.content_rule_sysctl_fs_protected_hardlinks
	if (sudo sysctl -a | grep -qxE "^fs\.protected_hardlinks = 1$"); then
		echo -e "${BLUE}[OK]${RESET}kernel -> fs.protected_hardlinks = 1"
	else
		sudo sysctl -q -n -w fs.protected_hardlinks="1"
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> fs.protected_hardlinks = 1"
		echo 'fs.protected_hardlinks = 1' | sudo tee /etc/sysctl.d/10-local-ssg.conf
	fi

	# xccdf_org.ssgproject.content_rule_sysctl_fs_protected_symlinks
	if (sudo sysctl -a | grep -qxE "^fs\.protected_symlinks = 1$"); then
		echo -e "${BLUE}[OK]${RESET}kernel -> fs.protected_symlinks = 1"
	else
		sudo sysctl -q -n -w fs.protected_symlinks="1"
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> fs.protected_symlinks = 1"
		echo 'fs.protected_symlinks = 1' | sudo tee -a /etc/sysctl.d/10-local-ssg.conf
	fi

	# xccdf_org.ssgproject.content_rule_sysctl_fs_suid_dumpable
	if (sudo sysctl -a | grep -qxE "^fs\.suid_dumpable = 0$"); then 
		echo -e "${BLUE}[OK]${RESET}kernel -> fs.suid_dumpable = 0"
	else
		sudo sysctl -q -n -w fs.suid_dumpable="0"
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> fs.suid_dumpable = 0"
		echo 'fs.suid_dumpable = 0' | sudo tee -a /etc/sysctl.d/10-local-ssg.conf
	fi

	# xccdf_org.ssgproject.content_rule_sysctl_kernel_randomize_va_space
	if (sudo sysctl -a | grep -qxE "^kernel\.randomize_va_space = 2$"); then
		echo -e "${BLUE}[OK]${RESET}kernel -> kernel.randomize_va_space = 2"
	else
		sudo sysctl -q -n -w kernel.randomize_va_space="2"
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> kernel.randomize_va_space = 2"
		echo 'kernel.randomize_va_space = 2' | sudo tee -a /etc/sysctl.d/10-local-ssg.conf
	fi

	# xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_tcp_syncookies
	if (sudo sysctl -a | grep -qxE "^net\.ipv4\.tcp_syncookies = 1$"); then
		echo -e "${BLUE}[OK]${RESET}kernel -> net.ipv4.tcp_syncookies = 1"
	else
		sudo sysctl -w net.ipv4.tcp_syncookies="1"
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> net.ipv4.tcp_syncookies = 1"
		echo 'net.ipv4.tcp_syncookies = 1' | sudo tee -a /etc/sysctl.d/10-local-ssg.conf
	fi

	# magic-sysrq-key
	if (sudo sysctl -a | grep -qxE "^kernel\.sysrq = 0$"); then
		echo -e "${BLUE}[OK]${RESET}kernel -> kernel.sysrq (Ctrl+Alt+Del) = 0"
	else
		sudo sysctl -q -n -w kernel.sysrq="0"
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> kernel.sysrq (Ctrl+Alt+Del) = 0"
		if [ -e /etc/sysctl.d/10-magic-sysrq.conf ]; then
			sudo sed -i 's/^kernel.sysrq = .*$/kernel.sysrq = 0/' /etc/sysctl.d/10-magic-sysrq.conf
		else
			echo 'kernel.sysrq = 0' | sudo tee -a /etc/sysctl.d/10-local-ssg.conf
		fi
	fi

	# https://github.com/nongiach/sudo_inject
	# https://github.com/carlospolop/hacktricks/tree/master/linux-unix/privilege-escalation#reusing-sudo-tokens
	# cat /proc/sys/kernel/yama/ptrace_scope
	if (sudo sysctl -a | grep -qxE "^kernel\.yama\.ptrace_scope = [^0]$"); then
		echo -e "${BLUE}[OK]${RESET}kernel -> kernel.ptrace_scope != 0"
	else
		sudo sysctl -q -n -w kernel.yama.ptrace_scope="1"
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> kernel.yama.ptrace_scope = 1"
		echo 'kernel.yama.ptrace_scope = 1' | sudo tee -a /etc/sysctl.d/10-local-ssg.conf
	fi


	# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
	# xccdf_org.ssgproject.content_rule_coredump_disable_backtraces
	# xccdf_org.ssgproject.content_rule_coredump_disable_storage
	if ! [ -e /etc/systemd/coredump.conf ]; then
		sudo touch "/etc/systemd/coredump.conf"
	fi

	if (grep -Eqx "^ProcessSizeMax=0$" /etc/systemd/coredump.conf); then
		echo -e "${BLUE}[OK]${RESET}kernel -> backtraces disabled -> ProcessSizeMax=0"
	else
		echo "ProcessSizeMax=0" | sudo tee -a /etc/systemd/coredump.conf
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> backtraces disabled -> ProcessSizeMax=0"
	fi

	if (grep -Eqx "^Storage=none$" /etc/systemd/coredump.conf); then
		echo -e "${BLUE}[OK]${RESET}kernel -> coredumps disabled -> Storage=none"
	else
		echo "Storage=none" | sudo tee -a /etc/systemd/coredump.conf
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> coredumps disabled -> Storage=none"
	fi


	# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
	# xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled
	if (grep -Eqx "^install rds /bin/true$" /etc/modprobe.d/rds.conf); then
		echo -e "${BLUE}[OK]${RESET}kernel -> 'install rds /bin/true' -> /etc/modprobe.d/rds.conf"
	else
		echo 'install rds /bin/true' | sudo tee /etc/modprobe.d/rds.conf
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> 'install rds /bin/true' -> /etc/modprobe.d/rds.conf"
	fi

	# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
	# xccdf_org.ssgproject.content_rule_kernel_module_tipc_disabled
	if (grep -Eqx "^install tipc /bin/true$" /etc/modprobe.d/tipc.conf); then 
		echo -e "${BLUE}[OK]${RESET}kernel -> 'install tipc /bin/true' -> /etc/modprobe.d/tipc.conf"
	else
		echo 'install tipc /bin/true' | sudo tee /etc/modprobe.d/tipc.conf
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> 'install tipc /bin/true' -> /etc/modprobe.d/tipc.conf"
	fi


	# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
	# xccdf_org.ssgproject.content_rule_grub2_enable_iommu_force
	if (grep -Eqx "^.*iommu=force.*$" /etc/default/grub); then
		echo -e "${BLUE}[OK]${RESET}kernel -> iommu=force -> /etc/grub/default"
	elif grep -q '^GRUB_CMDLINE_LINUX=.*iommu=.*"'  '/etc/default/grub' ; then
		# modify the GRUB command-line if an iommu= arg already exists
		sudo sed -i 's/\(^GRUB_CMDLINE_LINUX=".*\)iommu=[^[:space:]]*\(.*"\)/\1 iommu=force \2/'  '/etc/default/grub'
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> iommu=force -> /etc/grub/default"
	elif ! (grep -q '^GRUB_CMDLINE_LINUX=.*iommu=.*"'  '/etc/default/grub'); then
		# no iommu=arg is present, append it
		sudo sed -i 's/\(^GRUB_CMDLINE_LINUX=".*\)"/\1 iommu=force"/'  '/etc/default/grub'
		echo -e "${YELLOW}[UPDATED]${RESET}kernel -> iommu=force -> /etc/grub/default"
	fi

	# Add other kernel parameter changes here

	sudo update-grub

}

CheckKernel
