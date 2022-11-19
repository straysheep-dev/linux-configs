#!/bin/bash

# GPL-3.0-or-later

# shellcheck disable=SC2034

# https://kb.vmware.com/s/article/2146460
# https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_Kernel_Modules/#sect-generating-a-public-private-x509-key-pair

# Tested on:
# 	Ubuntu 20.04.x LTS
# 	Ubuntu 22.04.x LTS

# Shell script to sign VMware kernel modules after either 1) updating VMware or 2) updating the host's kernel
# It assumes you already have a dedicated X509 private key, created and controlled by you, with the public key loaded into the kernel for module signing
# This script will create the key pair for you, but you'll need to import the public key into the kernel for Secure Boot with moktuil
# NOTE: In some cases, you may need to re-import the public key at a later time. For example, after updating the UEFI/BIOS, or if you decide to make a new key each time.

# `mokutil` requires a password during the boot sequence to import keys into the database of shim.
# This password exists solely for this purpose, of ensuring you have physical access to the device during the mok manager prompts.
# Create an 8-16 character password using your **password manager** or write it down so you have it with you while the machine is offline in mok management.
# $ sudo mokutil --import /path/to/VMw.der
# enter the password you just created
# $ sudo reboot

# How this works:
# 1) Update the component (host kernel or VMware Workstation application)
# 2) Poweroff/reboot
# 3) Run VMware Workstation to start the build process for new kmods (`$ modinfo vmmon|vmnet` prior to this action will show no modules matching that name loaded)
# 4) Allow it to fail with "Unable to install all modules. See log /tmp/vmware-$USERNAME/... for details. (Exit code 1)"
# 5) When prompted again, cancel the install (the new kmods are built at this point)
# 6) Sign them (by running this script)
# 7) Reboot (failing to reboot after this will prevent the kernel from being able to accept and load the newly signed kmods, but modinfo vmmon|vmnet will show they are signed at this time)
# 8) Now you can launch VMware Workstation with the new kernel modules loaded

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

if [ "${EUID}" -eq 0 ]; then
	echo "Run this as a normal user. Sudo is used to elevate only specific commands."
	exit 1
fi

function CheckEnrolledKeys() {

	# This check could be more precise

	if ! (mokutil --list-enrolled | grep -qi "vmware"); then
		echo -e "[${YELLOW}i${RESET}]VMware module signing public key (the .der file) must be enrolled into the kernel:"
		echo ""
		echo "    MOK manager requires a password during the boot sequence to import keys into the database of shim."
		echo "    This password exists solely for this purpose, of ensuring you have physical access to the device during the MOK manager prompts."
		echo "    Create an 8-16 character password using your **password manager** or write it down so you have it with you while the machine is offline in mok management."
		echo ""
		echo -e "1. ${BOLD}$ sudo mokutil --import /path/to/public/key/VMw.der${RESET}"
		echo "2. Enter the password you just created"
		echo -e "3. ${BOLD}$ sudo reboot${RESET}"
		echo ""
	fi
}

if (lsmod | grep -q "vmmon") && (lsmod | grep -q "vmnet"); then

	echo -e "[${GREEN}✓${RESET}]vmmon / vmnet modules are currently loaded in the kernel."

elif [[ "$(modinfo -F signature vmnet)" == '' ]] || [[ "$(modinfo -F signature vmmon)" == '' ]]; then

	if ! [[ -e "$(modinfo -n vmnet)" ]] || ! [[ -e "$(modinfo -n vmmon)" ]]; then
		echo -e "[${BLUE}*${RESET}] Building new kernel modules..."
		echo "Looking error message: 'Unable to install all modules. See log /tmp/vmware-$USERNAME/... for details. (Exit code 1)'."
		echo "IT IS OK TO CANCEL HERE, KERNEL MODULES WILL BE SIGNED TO PROCEED."
		if (command -v vmware > /dev/null); then
			vmware ; if [ "$?" -eq 1 ]; then echo -e "[${BLUE}i${RESET}]Error code is 1, which is expected."; fi
		else
			echo -e "[${RED}i${RESET}]vmware command not found. Exiting."
			exit 1
		fi
	fi

	sleep 1

	if ! [[ -e '/var/lib/shim-signed/mok/VMw.der' ]]; then

		# Should add a prompt here so user can decline if a key already exists

		echo -e "[${GREEN}>${RESET}]Generating a signing key..."
		cd /var/lib/shim-signed/mok/ || (echo -e "[${RED}i${RESET}]Cannot find path to mok/ directory, quitting."; exit 1)

		# Configuration file taken from here:
		# https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_Kernel_Modules/#sect-generating-a-public-private-x509-key-pair
		# https://creativecommons.org/licenses/by-sa/4.0/
		# https://creativecommons.org/licenses/by-sa/4.0/legalcode
		echo '[ req ]
default_bits = 4096
distinguished_name = req_distinguished_name
prompt = no
string_mask = utf8only
x509_extensions = myexts

[ req_distinguished_name ]
#O = Organization                           # optional
CN = VMware Secure Boot Module Signing Key
#emailAddress = E-mail address              # optional

[ myexts ]
basicConstraints=critical,CA:FALSE
keyUsage=digitalSignature
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid' | sudo tee signing_key.config > /dev/null

		sudo openssl req -x509 -new -nodes -utf8 -sha256 -days 36500 -batch -config signing_key.config -outform DER -out VMw.der -keyout VMw.priv

		echo -e "[${GREEN}>${RESET}]Saved to: ${GREEN}/var/lib/shim-signed/mok/${RESET} as ${GREEN}VMw.der${RESET} and ${GREEN}VMw.priv${RESET}"
		echo -e ""
		echo -e "[${YELLOW}i${RESET}]Delete the .priv private key and (optionally) move the .priv file to a password manager if you wish to keep it."
		echo -e ""

		CheckEnrolledKeys
	fi

	# Additional check to ensure the modules were built against the latest kernel successfully
	#
	# The commands to obtain the patches were taken from here:
	# https://gitlab.com/kalilinux/documentation/kali-docs/-/tree/master/virtualization/install-vmware-host
	#
	# The commands in the script are escaped to appear correctly when echoed.
	# These are the commands without escaping:
	#     VMWARE_VERSION=$(grep player.product.version /etc/vmware/config | sed '/.*\"\(.*\)\".*/ s//\1/g')
	#     git clone -b workstation-${VMWARE_VERSION} https://github.com/mkubecek/vmware-host-modules.git /opt/vmware-host-modules-${VMWARE_VERSION}/
	#     cd /opt/vmware-host-modules-${VMWARE_VERSION}/
	#     make
	#     sudo make install
	if ! [[ -e "$(modinfo -n vmnet)" ]] || ! [[ -e "$(modinfo -n vmmon)" ]]; then
		echo -e "[${RED}*${RESET}]Modules failed to build against the running kernel."
		echo "Try the latest patch maintained by mkubecek from the openSUSE team:"
		echo "
VMWARE_VERSION=\$(grep player.product.version /etc/vmware/config | sed '/.*\\\"\(.*\)\\\".*/ s//\1/g')
git clone -b workstation-\${VMWARE_VERSION} https://github.com/mkubecek/vmware-host-modules.git /opt/vmware-host-modules-\${VMWARE_VERSION}/
cd /opt/vmware-host-modules-\${VMWARE_VERSION}/
make
sudo make install"
		exit 1
	fi

	echo "Signing vmmon..."
	sudo /usr/src/linux-headers-"$(uname -r)"/scripts/sign-file sha256 /var/lib/shim-signed/mok/VMw.priv /var/lib/shim-signed/mok/VMw.der "$(modinfo -n vmmon)"
	echo "Signing vmnet..."
	sudo /usr/src/linux-headers-"$(uname -r)"/scripts/sign-file sha256 /var/lib/shim-signed/mok/VMw.priv /var/lib/shim-signed/mok/VMw.der "$(modinfo -n vmnet)"

	echo -e ""
	echo -e "[${GREEN}✓${RESET}]Kernel modules signed."

else

	echo -e ""
	echo -e "[${BLUE}i${RESET}]vmmon / vmnet modules are signed. Reboot if you already haven't to load them into the kernel."
	echo -e ""

	CheckEnrolledKeys

fi
