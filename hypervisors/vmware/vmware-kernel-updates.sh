#!/bin/bash

# shellcheck disable=SC2034

# Link back to the original Fedora docs:
# Fedora Docs: https://docs.fedoraproject.org/en-US/quick-docs/how-to-use-vmware/
# License: CC BY-SA 4.0
# https://creativecommons.org/licenses/by-sa/4.0/legalcode

# This script uses the Kali version here:
# Kali Docs: https://gitlab.com/kalilinux/documentation/kali-docs/-/tree/master/virtualization/install-vmware-host
# License: GPL-3.0
# https://gitlab.com/kalilinux/documentation/kali-docs/-/blob/master/LICENSE

# You can create a script to take of this after a kernel update. Save it as /etc/kernel/install.d/99-vmmodules.install

export LANG=C

COMMAND="$1"
KERNEL_VERSION="${2:-$( uname -r )}"
BOOT_DIR_ABS="$3"
KERNEL_IMAGE="$4"

VMWARE_VERSION=$(grep player.product.version /etc/vmware/config | sed '/.*\"\(.*\)\".*/ s//\1/g')

ret=0

case "${COMMAND}" in
    add)
       [ -z "${VMWARE_VERSION}" ] && exit 0

       git clone -b workstation-"${VMWARE_VERSION}" https://github.com/mkubecek/vmware-host-modules.git /opt/vmware-host-modules-"${VMWARE_VERSION}"/
       cd /opt/vmware-host-modules-"${VMWARE_VERSION}"/ || exit 1
       make VM_UNAME="${KERNEL_VERSION}"
       make install VM_UNAME="${KERNEL_VERSION}"

       ((ret+=$?))
       ;;
    remove)
        exit 0
        ;;
    *)
        usage
        ret=1;;
esac

exit ${ret}
