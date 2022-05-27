#!/bin/bash

# Set "EnableMediaRouter": false, then add the following to stop mdns listener:
# chrome://flags => enable-webrtc-hide-local-ips-with-mdns => false

function isRoot() {
        if [ "${EUID}" -ne 0 ]; then
                echo "You need to run this script as root"
                exit 1
        fi
}

isRoot

function setupChromium() {
        mkdir -p /etc/chromium-browser/policies/managed
        mkdir -p /etc/chromium-browser/policies/recommended

        if [ -e ./chromium-policies.json ]; then
		cat ./chromium-policies.json  > /etc/chromium-browser/policies/managed/policies.json
	else
		curl -Lf 'https://raw.githubusercontent.com/straysheep-dev/linux-configs/main/web-browsers/chromium/chromium-policies.json' > /etc/chromium-browser/policies/managed/policies.json
		if (sha256sum /etc/chromium-browser/policies/managed/policies.json | grep -qx '518c8dbf3477f0264902dccb3e92e98306b9ec8ffb664277128cc7336acf4c10  /etc/chromium-browser/policies/managed/policies.json'); then
			echo "OK"
		else
			echo '[!]Bad signature for policies.json'
		fi
	fi
}

setupChromium
