#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2025 straysheep-dev

# shellcheck disable=SC2034

# This script requires sudo or root privileges to review kernel params.
# check-kernel.sh is meant to enumerate the running kernel state for visibility into any issues,
# misconfigurations, or security gaps.
#
# This file replaces the old "check-kernel.sh" script which actually fixes any misconfigurations.
# That script should be updated to match the logic here, for easier maintenance.

# Documentation and References:
# https://www.gnu.org/software/bash/manual/bash.html#Here-Strings
# https://www.shellcheck.net/wiki/SC2013

# Colors and color printing code taken directly from:
# https://github.com/carlospolop/PEASS-ng/blob/master/linPEAS/builder/linpeas_parts/linpeas_base.sh
C=$(printf '\033')
RED="${C}[1;31m"
SED_RED="${C}[1;31m&${C}[0m"
GREEN="${C}[1;32m"
SED_GREEN="${C}[1;32m&${C}[0m"
YELLOW="${C}[1;33m"
SED_YELLOW="${C}[1;33m&${C}[0m"
RED_YELLOW="${C}[1;31;103m"
SED_RED_YELLOW="${C}[1;31;103m&${C}[0m"
BLUE="${C}[1;34m"
SED_BLUE="${C}[1;34m&${C}[0m"
ITALIC_BLUE="${C}[1;34m${C}[3m"
LIGHT_MAGENTA="${C}[1;95m"
SED_LIGHT_MAGENTA="${C}[1;95m&${C}[0m"
LIGHT_CYAN="${C}[1;96m"
SED_LIGHT_CYAN="${C}[1;96m&${C}[0m"
LG="${C}[1;37m" #LightGray
SED_LG="${C}[1;37m&${C}[0m"
DG="${C}[1;90m" #DarkGray
SED_DG="${C}[1;90m&${C}[0m"
NC="${C}[0m"
UNDERLINED="${C}[5m"
ITALIC="${C}[3m"

kmod_list="$(lsmod | grep -Pv "^Module\s+Size\s+Used by$" | awk '{print $1}')"
sig_data_file='/tmp/kmod_sig_data.txt'
unsigned_module_list='/tmp/unsigned_modules.txt'
sig_data_fields='sig_id:
signer:
sig_key:
sig_hashalgo:'

# Secure Boot
echo -e "\n${ITALIC}${YELLOW}SECUREBOOT STATE${NC}"
if command -v mokutil >/dev/null
then
    sb_state="$(mokutil --sb-state)"
    echo "    $sb_state" | sed -E "s/enabled/${SED_GREEN}/; s/disabled/${SED_RED}/"
fi

# Kernel protections, including kernel params
echo -e "\n${ITALIC}${YELLOW}KERNEL PROTECTIONS${NC}"
lockdown_state="$(cat /sys/kernel/security/lockdown)"
if [[ "$lockdown_state" == *"[none]"* ]]
then
    echo "    ${RED}[WARN]${NC} /sys/kernel/security/lockdown: ${RED}[none]${NC}"
elif [[ "$lockdown_state" == *"[integrity]"* ]]
then
    echo "    ${GREEN}[OK]${NC} /sys/kernel/security/lockdown: ${GREEN}[integrity]${NC}"
elif [[ "$lockdown_state" == *"[confidentiality]"* ]]
then
    echo "    ${GREEN}[OK]${NC} /sys/kernel/security/lockdown: ${GREEN}[confidentiality]${NC}"
fi

# /etc/sysctl.d/README.sysctl
# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-standard.html
# After making any changes, please run "service procps reload" (or, from
# a Debian package maintainer script "deb-systemd-invoke restart procps.service").
# xccdf_org.ssgproject.content_rule_sysctl_fs_protected_hardlinks
# xccdf_org.ssgproject.content_rule_sysctl_fs_protected_symlinks
# xccdf_org.ssgproject.content_rule_sysctl_fs_suid_dumpable
# xccdf_org.ssgproject.content_rule_sysctl_kernel_randomize_va_space
# xccdf_org.ssgproject.content_rule_sysctl_net_ipv4_tcp_syncookies
# https://github.com/nongiach/sudo_inject
# https://github.com/carlospolop/hacktricks/tree/master/linux-unix/privilege-escalation#reusing-sudo-tokens
kernel_params="$(sudo sysctl -a)"

hardened_params='fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0
kernel.randomize_va_space = 2
net.ipv4.tcp_syncookies = 1
kernel.sysrq = 0
kernel.tainted = 0
kernel.yama.ptrace_scope = 1'

while IFS= read -r param
do
    if echo "$kernel_params" | grep -Pqx "^$param$"
    then
        echo -e "    ${GREEN}[OK]${NC} $param"
    else
        echo -e "    ${RED}[WARN]${NC} $param"
    fi
done <<< "$hardened_params"

# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
# xccdf_org.ssgproject.content_rule_coredump_disable_backtraces
# xccdf_org.ssgproject.content_rule_coredump_disable_storage
coredump_settings='ProcessSizeMax=0
Storage=none'

if [ -e /etc/systemd/coredump.conf ]; then
    while IFS= read -r setting
    do
        if (grep -Eqx "^$setting$" /etc/systemd/coredump.conf)
        then
            echo -e "    ${GREEN}[OK]${NC}/etc/systemd/coredump.conf: $setting"
        else
            echo -e "    ${RED}[WARN]${NC} /etc/systemd/coredump.conf: $setting not set"
        fi
    done <<< "$coredump_settings"
else
    echo -e "    ${RED}[WARN]${NC} /etc/systemd/coredump.conf does not exist"
fi

# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
# xccdf_org.ssgproject.content_rule_kernel_module_rds_disabled
# xccdf_org.ssgproject.content_rule_kernel_module_tipc_disabled
modprobe_settings='install rds /bin/true
install tipc /bin/true'

while IFS= read -r setting
do
    for file in /etc/modprobe.d/*
    do
        if (grep -Eqx "^$setting$" "$file")
        then
            setting_found='1'
        else
            setting_found='0'
        fi
    done
    if [[ "$setting_found" == '1' ]]
    then
        echo -e "    ${GREEN}[OK]${NC} $setting"
    else
        echo -e "    ${RED}[WARN]${NC} $setting not set under /etc/modprobe.d/*"
    fi
done <<< "$modprobe_settings"

# https://static.open-scap.org/ssg-guides/ssg-ubuntu1804-guide-cis.html
# xccdf_org.ssgproject.content_rule_grub2_enable_iommu_force
grub_settings='iommu=force'

if (grep -Eqx "^GRUB_CMDLINE_LINUX.*iommu=force.*$" /etc/default/grub); then
    echo -e "    ${GREEN}[OK]${NC} /etc/default/grub: iommu=force"
else
    echo -e "    ${RED}[WARN]${NC} /etc/default/grub: iommu=force not set"
fi

# Kernel module information
# Example data to review. Get a unique list of each module's signature details, and show any modules that aren't signed
# sig_id:         PKCS#7
# signer:         Build time autogenerated kernel key
# sig_key:        AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
# sig_hashalgo:   sha512
echo -e "\n${ITALIC}${YELLOW}UNSIGNED KERNEL MODULES${NC}"
if [[ -e /sbin/modinfo ]]
then
    for module in $kmod_list
    do
        sig_data="$(/sbin/modinfo "$module" | grep -A 5 -P "^sig_id:" | tee -a "$sig_data_file")"
        if [[ -z "$sig_data" ]]
        then
            echo -e "    ${RED}[WARN]${NC} $module" > "$unsigned_module_list"
        fi
    done

    if [[ -e "$unsigned_module_list" ]]
    then
        cat "$unsigned_module_list"
    else
        echo -e "    ${ITALIC}${GREEN}None${NC}"
    fi

    echo -e "\n${ITALIC}${YELLOW}UNIQUE SIGNATURE DATA${NC}"
    for field in $sig_data_fields
    do
        echo -e "\n    ${YELLOW}FIELD: $field${NC}"
        grep -P "^$field" "$sig_data_file" | sort | uniq -c | sort -nr
    done

    # Cleanup
    for file in "$sig_data_file" "$unsigned_module_list"
    do
        rm -f "$file"
    done
else
    echo -e "    ${YELLOW}[ERROR]${NC} modinfo command not found"
fi