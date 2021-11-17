#!/bin/bash

# Run manually for system maintenance

# Root check
if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root."
    exit 1
fi

function runMaintenance() {

        apt update && \
        apt upgrade -y

        sleep 2

        apt autoremove --purge -y
        sleep 2
        apt-get clean

	if (command -v snap); then
		snap refresh
	fi
	HYPERVISOR="$(cat /sys/devices/virtual/dmi/id/bios_ve* | grep -E "(VMware|VirtualBox)")"
	if ! [[ "$HYPERVISOR" == "" ]]; then
		echo "$HYPERVISOR detected. Checking disk usage..."
		DISK_USAGE="$(du -h -d1 / 2>/dev/null | grep "^.*/$" | cut -d 'G' -f 1)"
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
		fi
	fi
}
runMaintenance
