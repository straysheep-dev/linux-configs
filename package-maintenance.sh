#!/bin/bash

# Run manually for system maintenance

# Root check
if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root."
    exit 1
fi

function runMaintenance() {

	if (command -v apt > /dev/null); then
		apt update && \
		apt upgrade -y

		sleep 1

		apt autoremove --purge -y
		sleep 1
		apt-get clean

	elif (command -v dnf > /dev/null); then
		dnf upgrade -y
		
		sleep 1
		
		dnf autoremove -y
		dnf clean all

	if (command -v snap > /dev/null); then
		snap refresh
	fi
	HYPERVISOR="$(grep -E "(VMware|VirtualBox)" /sys/devices/virtual/dmi/id/bios_ve*)"
	if ! [[ "$HYPERVISOR" == "" ]]; then
		echo "$HYPERVISOR detected."
		echo "Checking disk usage..."
		DISK_USAGE="$(df -h | grep -P "/$" | sed 's/\s\s*/ /'g | cut -d ' ' -f 3 | cut -d '.' -f 1)"
		if [[ "$DISK_USAGE" -gt "20" ]]; then
			echo "Disk usage above 20GB."
			echo "Compact virtual appliance with one of the following:"
			echo ""
			echo "VirtualBox (vdi):"
			echo "$ VBoxManage modifyhd --compact /path/to/*.vdi"
			echo ""
			echo "VMware & VirtualBox (vmdk|other):" 
			echo "$ dd if=/dev/zero of=zerofill bs=1M status=progress"
			echo "$ rm zerofill"
			echo "$ poweroff"
			echo "Clone VM > Full Clone"
		else
			echo "OK"
		fi
	fi
}

runMaintenance
