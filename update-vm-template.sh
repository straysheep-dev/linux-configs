#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2025 straysheep-dev

# shellcheck disable=SC2034
# shellcheck disable=SC2221
# shellcheck disable=SC2222
# shellcheck disable=SC2029

# Automate updating virtual machine templates. See the help output below for details.

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
BOLD="${C}[01;01m"
SED_BOLD="${C}[01;01m&${C}[0m"

# Usage options
function HelpMenu() {
    echo -e "${BOLD}NAME${NC}"
    echo -e "      ${LIGHT_MAGENTA}update-vm-template${NC}"
    echo -e ""
    echo -e "${BOLD}SYNOPSIS${NC}"
    echo -e "      A wrapper to automate updating virtual machine templates."
    echo -e ""
    echo -e "${BOLD}DESCRIPTION${NC}"
    echo -e "      In cases where rebuilding or redeploying isn't necessary. The idea is if you are building server or desktop"
    echo -e "      VM's for general use, it's more resource efficient to maintain a template image that gets updated regularly,"
    echo -e "      and create short-lived clones of this image for any workloads as needed."
    echo -e ""
    echo -e "      This script is designed to launch, update, poweroff, and snapshot template VM's in a repeatable way."
    echo -e "      Both scheduled (headless) or on-demand (interactive) use cases work."
    echo -e ""
    echo -e "      The primary method (as of now) is ssh + cmd. This assumes you can SSH into the target and run the command."
    echo -e ""
    echo -e "      Ideally Ansible can be used in the future to make this more modular, so you can supply any"
    echo -e "      role and playbook you need."
    echo -e ""
    echo -e "      In any case, this could run as a scheduled job."
    echo -e ""
    echo -e "${BOLD}USAGE${NC}"
    echo -e "      ${LIGHT_MAGENTA}$0${NC} ${DG}-hv${NC} ${GREEN}qemu${NC} ${DG}-vm${NC} ${LIGHT_CYAN}kali-dev${NC} ${DG}-u${NC} ${LIGHT_CYAN}kali${NC} ${DG}-c${NC} ${LG}'/usr/local/bin/update.sh'${NC} ${DG}-sn${NC} ${LG}updates_20250101${NC}"
    echo -e ""
    echo -e "${BOLD}MAIN ARGUMENTS${NC}"
    echo -e ""
    echo -e "     -hv, --hypervisor [qemu|virtualbox|vmware|hyper-v]"
    echo -e "             The hypervisor you're using. This is often VMware, VirtualBox, Hyper-V, or QEMU. Currently only QEMU is supported."
    echo -e ""
    echo -e "     -vm, --vm-name <vm-name>"
    echo -e "             The name of the vm template you'd like to power on and update."
    echo -e ""
    echo -e "     -u, --username <vm-name>"
    echo -e "             The name of the user on the VM if using SSH."
    echo -e ""
    echo -e "     -c, --command '<cmd>'"
    echo -e "             A quoted string of commands to execute on the guest."
    echo -e ""
    echo -e "     -sn, --snapshot-name <snapshot-name>"
    echo -e "             The name of the snapshot."
    echo -e ""
    echo -e "${BOLD}OPTIONAL ARGUMENTS${NC}"
    echo -e ""
    echo -e "     -v, --verbose"
    echo -e "             Show the output of commands being executed on the guest. Without -v this is sent to /dev/null."
	exit 0
}

# Show help if there aren't any arguments
if [[ $# -eq 0 ]]; then
    HelpMenu
fi

# This is the easiest way to do this in bash, but it won't work in other shells
# See getopt-parse under /usr/share/doc/util-linux/examples
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -hv|--hypervisor)
            HYPERVISOR="$2"
            shift # past argument
            shift # past value
            ;;
        -vm|--vm-name)
            VM_NAME="$2"
            shift # past argument
            shift # past value
            ;;
        -u|--username)
            USERNAME="$2"
            shift # past argument
            shift # past value
            ;;
        -c|--command)
            COMMAND="$2"
            shift # past argument
            shift # past value
            ;;
        -sn|--snapshot-name)
            SNAPSHOT_NAME="$2"
            shift # past argument
            shift # past value
            ;;
        -v|--verbose)
            VERBOSE='1'
            shift # past argument
            shift # past value
            ;;
        -h|--help)
            HelpMenu
            ;;
        -*|--*)
            echo "Unknown option $1"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # save positional arg
            shift # past argument
            ;;
    esac
done

# Start logic blocks
if [[ -z "$HYPERVISOR" ]] || [[ -z "$VM_NAME" ]] || [[ -z "$USERNAME" ]] || [[ -z "$COMMAND" ]] || [[ -z "$SNAPSHOT_NAME" ]]
then
    HelpMenu
fi

if ! dpkg -S "$HYPERVISOR" >/dev/null
then
    echo -e "[${BLUE}*${NC}]${YELLOW}$HYPERVISOR not in found in the package list. Check the --help menu for usage.${NC}"
    exit 1
fi

if [[ "$HYPERVISOR" == "qemu" ]]
then
    # Ensure necessary binaries exist
    if ! command -v virsh >/dev/null && command -v qemu-system-x86_64 >/dev/null
    then
        echo -e "[${YELLOW}*${NC}] You must install ${YELLOW}qemu-system-x86_64${NC} and ${YELLOW}virt-manager${NC} to use this utility."
        exit 1
    fi

    # Confirm the VM exists
    if ! virsh list --all | grep "$VM_NAME" > /dev/null
    then
        echo -e "[${BLUE}*${NC}] ${YELLOW}$VM_NAME not found. Printing all available VMs...${NC}"
        virsh list --all
        exit 1
    fi

    # Power up the VM
    echo -e ""
    echo -e "[${BLUE}*${NC}]Starting $VM_NAME..."
    virsh start "$VM_NAME" >/dev/null

    # Pause for the VM to boot and obtain an IP
    while ! virsh domifaddr "$VM_NAME" --source lease >/dev/null
    do
        echo "[${BLUE}*${NC}] Waiting 10 seconds for VM to boot..."
        sleep 10
    done

    # Obtain the guest's IP, this PCRE is imprecise but works fine for now
    VM_IP=$(virsh domifaddr "$VM_NAME" --source lease | awk '{print $4}' | grep -Po "(([0-9]){1,3}\.){3}([0-9]){1,3}")

    # Prefer SSH, it's universally available
    # We acutally want the $COMMAND variable to be expanded client-side before sending it to the target VM
    # https://github.com/koalaman/shellcheck/wiki/SC2029
    echo -e "[${BLUE}*${NC}]Connecting via ${LIGHT_MAGENTA}$USERNAME${NC}${BOLD}@${NC}${LIGHT_CYAN}$VM_IP${NC}..."
    if [[ "$VERBOSE" == "1" ]]
    then
        while ! ssh "$USERNAME"@"$VM_IP" "$COMMAND"
        do
            echo -e "[${BLUE}*${NC}]Waiting 10 seconds for SSH to become available..."
            sleep 10
        done
    else
        while ! ssh "$USERNAME"@"$VM_IP" "$COMMAND" > /dev/null
        do
            echo -e "[${BLUE}*${NC}]Waiting 10 seconds for SSH to become available..."
            sleep 10
        done
    fi

    # TO DO: Try qemu-agent-command first, then fall back to SSH
    # SSH is preferred because qemu-guest-agent is not always installed

    # Shutdown the VM
    echo -e ""
    echo -e "[${BLUE}*${NC}]Shutting down $VM_NAME..."
    while (virsh list --all | grep "$VM_NAME" | grep running >/dev/null); do
        virsh shutdown "$VM_NAME" >/dev/null
        echo -e "    waiting 5 seconds..."
        sleep 5
    done
    echo -e "[${BLUE}*${NC}]$VM_NAME shutdown successfully."

    # Take a snapshot if everything was successful
    # https://wiki.libvirt.org/Determining_version_information_dealing_with_unknown_procedure.html
    if virsh -v | grep -Pqx "(\d){2}(\.\d+){2,}"; then
        echo -e "[${BLUE}*${NC}]Taking snapshot $SNAPSHOT_NAME..."
        if virsh snapshot-create-as "$VM_NAME" "$SNAPSHOT_NAME" --description "Template update at $(date +%F_%T)" >/dev/null; then
            echo -e "[${BLUE}*${NC}]Snapshot created. Refresh the snapshot list in the GUI."
        else
            echo -e "[${RED}*${NC}]Error, quitting..."
            exit 1
        fi
    else
        echo -e "[${YELLOW}*${NC}]Internal snapshots on VM's with NVRAM require libvirtd version 10.0.0 or higher (Ubuntu 24.04)"
        echo -e "   See: https://github.com/virt-manager/virt-manager/issues/851"
    fi

fi