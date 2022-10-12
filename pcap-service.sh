#!/bin/bash

# pcap as a service, capture network data for later processing with tools like Zeek and RITA

# This script was built from the following exmaples:
# https://github.com/0ptsec/optsecdemo
# https://github.com/bettercap/bettercap/blob/master/bettercap.service

# Additional resources:
# https://github.com/zeek/zeek
# https://github.com/activecm/rita

if ! [ -e /opt/pcaps ]; then
	echo "[i]Creating /opt/pcaps..."
	mkdir -p /opt/pcaps
fi

CAP_IFACE="$(ip a | grep -oP "^\d+:\s+\w+:" | cut -d ':' -f 2 | sed 's/[[:space:]]//g' | grep -P "^e\w+")"

echo "[>]Detecting network interfaces..."
echo "$(ip a | grep -oP "^\d+:\s+\w+:" | cut -d ':' -f 2 | sed 's/[[:space:]]//g')"
echo ""
echo "[i]Which interface would you like to capture from?"
until [[ $CAP_IFACE_CHOICE =~ ^([[:alnum:]]+)$ ]]; do
	read -rp "Interface: " -e -i "$CAP_IFACE" CAP_IFACE_CHOICE
done

# cat /etc/systemd/system/packet-capture.service
echo "[Unit]
Description=Packet capture service for network forensics
Documentation=https://github.com/straysheep-dev/network-visibility, https://www.activecountermeasures.com/raspberry-pi-network-sensor-webinar-qa/
Wants=network.target
After=network.target

[Service]
Type=simple
PermissionsStartOnly=true
ExecStart=/usr/bin/nice -n 15 /usr/sbin/tcpdump -i -Z nobody $CAP_IFACE_CHOICE -G 3600 -w '/opt/pcaps/$(hostname -s).%%Y%%m%%d%%H%%M%%S.pcap' '((tcp[13] & 0x17 != 0x10) or not tcp)'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/packet-capture.service

# tcpdump still drops privileges, will restart automatically
# use %% to escape %'s in systemd service units
# root:root /opt/pcaps
# tcpdump:tcpdump /opt/pcaps/hostname.%%Y%%m%%d%%H%%M%%S.pcap
# $(subshell) is encased within two double quotes ""'s to safely handle 'hostname -s'

echo "[i]Reloading all systemctl service files..."
systemctl daemon-reload && \
echo "[i]Enabling packet-capture.service..."
systemctl enable packet-capture.service && \
echo "[i]Starting packet-capture.service"
systemctl start packet-capture.service && \
echo "[✓]Done."
echo ""
systemctl status packet-capture.service
