#!/bin/bash

# Script to change between the pcscd daemon included with the yubioath-desktop snap, and the pcscd daemon from apt.
# Useful if you use both otp codes and gpg functions via a yubikey, yubikeys cannot access both daemons simultaneously.
# Or if you use multiple yubikeys with same / different identities and or otp codes.
# Install this script to your preferred location, with the correct permissions (root:root 755 or root:$USERNAME 750) and add it to your PATH.

if [ "${EUID}" -eq 0 ]; then
        echo "Run this as a normal user. Sudo is used to elevate only specific commands."
        exit 1
fi

if [ "${1}" == 'gpg' ]; then
        # Allows ssh, code signing, and other operations with connected yubikey
        echo "[i]GPG mode"
        sudo systemctl stop snap.yubioath-desktop.pcscd.service
        sudo systemctl restart pcscd

        # Uncomment the following two lines if using two yubikeys, that do not share the same gpg identity.
        #echo "[i]If changing key identities; unplug the first key, then re-run."
        #pkill gpg-agent ; pkill ssh-agent ; pkill pinentry ; eval $(gpg-agent --daemon --enable-ssh-support)

        # https://github.com/drduh/YubiKey-Guide#switching-between-two-or-more-yubikeys
        # Uncomment the following line if using two yubikeys that share the same gpg identity.
        #gpg-connect-agent "scd serialno" "learn --force" /bye

        gpg-connect-agent updatestartuptty /bye

elif [ "${1}" == 'otp' ]; then
        # Connects yubikey to the yubioath-desktop snap application to view OTP codes
        echo "[i]OTP mode"
        echo "[i]If changing keys, unplug the first key, then re-run this script in otp mode."
        sudo systemctl stop pcscd
        sudo systemctl restart snap.yubioath-desktop.pcscd.service

else
        echo "Usage: yubi-mode otp | yubi-mode gpg"
fi
