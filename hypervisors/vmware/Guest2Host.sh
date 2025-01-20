#!/bin/bash

# Quicker way to run this command.
# Place this script in /opt
# sudo ln -s /opt/.../Guest2Host.sh /usr/local/bin/Guest2Host

VM="$(find "$HOME" -type f -name "$1".vmx)"
SRC="$2"
DST="$3"

if [[ "$VM" == '' ]] ; then
        echo "Enter the name of the VM (.vmx file) as an argument"
elif [[ "$2" == '' ]]; then
	echo "Enter the source file as argument 2."
elif [[ "$3" == '' ]]; then
	echo "Enter the destination file as argument 3."
else
        echo "$VM found."
	echo ''
	if (command -v vmrun > /dev/null); then
		echo "[i] Start Time: $(date +%Y%m%d.%T)"
		vmrun -T ws CopyFileFromGuestToHost "$VM" "$SRC" "$DST"
		echo "[i] End Time: $(date +%Y%m%d.%T)"
	else
		echo "Missing vmrun command. Quitting."
		exit 1
	fi
fi
