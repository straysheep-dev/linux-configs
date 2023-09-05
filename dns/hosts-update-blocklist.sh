#!/bin/bash

# Download the latest blocklist and check for errors
# Run as root via cron to install automatically or run as root manually to update immediately

# Crontab to run every other day at noon:
# 0 12 * * 2,4,6 /bin/bash /opt/hosts-update-blocklist.sh
# Do not run more often than once every 5 minutes: <https://urlhaus.abuse.ch/api/#tos>

# Export path if using `crontab -e` and not writing to /etc/crontab
# Cron does not use the expected environment variables (it's defaults are SHELL=/bin/sh && PATH=/usr/bin:/bin)
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

LOGFILE='hosts-update-blocklist'

# Root check
if [ "${EUID}" -ne 0 ]; then
	echo "This script must be run as root. Quitting."
	exit 1
fi

# Create the logging configuration if it doesn't exist
if ! [ -e /etc/logrotate.d/"$LOGFILE" ]; then
	echo "# Logging configuration for $LOGFILE shell script
/var/log/$LOGFILE {
	nocompress
	monthly
	rotate 4
	missingok
	notifempty
	su root root
	create 0644 root root
}" > /etc/logrotate.d/"$LOGFILE"
fi

# Backup current hosts file before installing the new one
if [ -e '/etc/hosts' ]; then
	cp -n /etc/hosts /etc/hosts.bkup
fi

# Make a temporary working directory to work with these files alone
if [ -d /tmp/tmp.updatehosts ]; then
	rm -rf /tmp/tmp.updatehosts
fi

mkdir /tmp/tmp.updatehosts
UPDATE_DIR='/tmp/tmp.updatehosts'
export UPDATE_DIR

cd "$UPDATE_DIR" || (echo "Failed creating temporary directory. Quitting." && echo "# [WARNING]: $(date +%Y-%m-%d) $(date +%H:%M:%S) Failed creating temporary directory." >> /var/log/"$LOGFILE" && exit)

# Download blocklists
curl -sS 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts' > 'hosts.txt'
# add more blocklists here

# Make sure download was successful and filetype matches what's expected (ASCII text, no UTF characters)
for list in ./*.txt; do
	if ! (file "$list" | grep -Pqx "^./.*\.txt:\s(ASCII text|ASCII text, with CRLF line terminators)$"); then
		echo 'One or more lists not plain text. Quitting.'
		echo "# [WARNING]: $(date +%Y-%m-%d) $(date +%H:%M:%S) One or more lists not plain text." >> /var/log/"$LOGFILE"
		cd ~/ || exit
		rm -rf "$UPDATE_DIR"
		exit
	fi
done

function checkFormatting() {
	# Here we want to make sure every line is properly formatted

	# Use for loops instead of ls grep, if using wildcard * filename matching in the future
	# Check for any lines not beginning with #, \s+#, 0.0.0.0, 127.0.0.1, fe80::1, ff00::0, ff02::(1|2|3), or empty
	grep -Pv "^(#|\s+#|(0\.){3}0|127\.0\.0\.1|(255.){3}255|::1|fe80::1[^\d+]|ff00::0[^\d+]|ff02::(1|2|3)[^\d+]|^$)" ./*.txt >> checkerrors.out

	# Append a failure summary to log file if checkerrors.out was not empty.
	# checkerrors.out contains the lines that did not pass the formatting check
	if ! (file checkerrors.out | grep -qx "^checkerrors.out: empty$") ; then
		{
			echo "# [WARNING]: $(date +%Y-%m-%d) $(date +%H:%M:%S) failed formatting check."
			echo '==================================================================================='
			echo '################################ BEGIN ERRORS #####################################'
			echo ''
			cat checkerrors.out
			echo ''
			echo '################################# END ERRORS ######################################'
			echo '==================================================================================='
		} >> /var/log/"$LOGFILE"

		echo 'Failed formatting check. Quitting.'
		cd ~/ || exit
		rm -rf "$UPDATE_DIR"
		exit
	fi
}

checkFormatting

# Automatically install the updated hosts file after passing all checks
cp ./hosts.txt /etc/hosts

# Add the system's hostname to /etc/hosts
if ! (grep -Pq "^127.0.1.1\s$(hostname)$" /etc/hosts); then
	echo "
# System hostname
127.0.1.1 $(hostname)" | tee -a /etc/hosts > /dev/null
fi

# Log successful installation of updated hosts file
echo "[OK]: $(date +%Y-%m-%d) $(date +%H:%M:%S) hosts" >> /var/log/"$LOGFILE"

cd ~/ || exit
rm -rf "$UPDATE_DIR"

# Reload the hosts file, clear DNS cache
# https://github.com/StevenBlack/hosts#reloading-hosts-file
if (systemctl is-active network-manager > /dev/null); then
	service network-manager restart
elif (systemctl is-active networking.service > /dev/null); then
	systemctl restart networking.service
fi


exit
