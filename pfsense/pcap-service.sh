#!/bin/sh

# MIT License

# This script is a self contained service / cron task. It's made to run on pfSense using /bin/sh instead of /bin/tcsh.
# It writes its own cron task, copies itself to the path you specify, can auto restart if the process ends, and writes / rotates pcaps for logging
# See this section and it's resources for more details: https://github.com/straysheep-dev/cheatsheets/blob/main/pfsense/pfsense.md#logging-network-traffic
# Thanks and credits:
# https://github.com/0ptsec/optsecdemo
# https://www.activecountermeasures.com/raspberry-pi-network-sensor-webinar-qa/
# https://github.com/william-stearns (wstearns-ACM) in the Threat Hunter Community Discord
# https://unix.stackexchange.com/questions/194863/delete-files-older-than-x-days (user basic6's answer)

# Hardcode these to store them in this script for cron to read. Examples included by default, but change these to whatever you need.
# For the PCAP_PATH, it's recommended to use an external storage device on real hardware. See the following link for how to set this up:
# https://github.com/straysheep-dev/cheatsheets/blob/main/pfsense/pfsense.md#external-storage
PCAP_PATH='/var/log/pcaps'
DAYS='30'
IFACE='em3'
SCRIPT_NAME='pcap-service.sh'
SCRIPT_PATH='/opt/scripts'

if [ "$PCAP_PATH" = '' ] || [ "$IFACE" = '' ] || [ "$DAYS" = '' ] || [ "$SCRIPT_PATH" = '' ] || [ "$SCRIPT_NAME" = '' ]; then
	echo "One or more variables are empty. Quitting."
	exit 1
fi

if ! [ "$(whoami)" = 'root' ]; then
	echo "Must be run as root. Quitting."
	exit 1
	# Sudo is not used here because it's not available by default in pfSense.
	# It's still recommended to install sudo, but this script works without it.
fi

if ! [ -e "$SCRIPT_PATH"/"$SCRIPT_NAME" ]; then
	mkdir -p -m 755 "$SCRIPT_PATH"
	if ! (cp "$SCRIPT_NAME" "$SCRIPT_PATH"; chmod 755 "$SCRIPT_PATH"/"$SCRIPT_NAME"); then
		echo "Script not found. Quitting."
		exit 1
	fi
fi

if ! [ -e "$PCAP_PATH" ]; then
	mkdir -p -m 770 "$PCAP_PATH"
fi

# Create a logsync group
pw groupadd logsync
# Set the pcap storage path to be owned by nobody:logsync, so we can drop tcpdump privileges to nobody and it can still write to that path
chown nobody:logsync "$PCAP_PATH"
# Allow nobody and members of the logsync group to read/write/traverse the path
chmod 770 "$PCAP_PATH"
# Adds root to the logsync group. You can also add your unprivileged user(s) to the logsync group for access
pw groupmod logsync -m "$(whoami)"

# Write our own cron task if it doesn't exist
# Rotates the pcap files automatically
# Restarts the tcpdump capture process if it's not running
if ! [ -e /etc/cron.d/pcap-service ]; then

	echo "# Cron task to rotate pcaps
# Rotates pcap files under $PCAP_PATH based on the range of time in DAYS
# For example, +60 means the last 60 days of pcaps are maintained

* 0  * * * root /usr/bin/find $PCAP_PATH -type f -mtime +$DAYS -delete

# Checks if the tcpdump process is running, if not, restarts it.
*/1 *  * * * root /bin/sh $SCRIPT_PATH/$SCRIPT_NAME" | tee /etc/cron.d/pcap-service

fi

# This kicks off the tcpdump process on first run, and is used by cron to continually check for the process
# Exits if the process is found, restarts the tcpdump process if not
if (pgrep -f "tcpdump -i $IFACE -Z nobody -G 3600 -w $PCAP_PATH/pfSense.%Y%m%d%H%M%S.pcap"); then
	exit
elif ! (pgrep -f "tcpdump -i $IFACE -Z nobody -G 3600 -w $PCAP_PATH/pfSense.%Y%m%d%H%M%S.pcap"); then
	/usr/sbin/tcpdump -i "$IFACE" -Z nobody -G 3600 -w "$PCAP_PATH"/pfSense.%Y%m%d%H%M%S.pcap '((tcp[13] & 0x17 != 0x10) or not tcp)' &
fi
