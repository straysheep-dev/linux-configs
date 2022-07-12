#!/bin/bash

# Prepare the latest blocklist and check for parsing errors
# Run as root via cron to install automatically or run as root manually to update immediately

# Crontab to run every 12 hours:
# 0 */12 * * * /bin/bash /opt/unbound-update-blocklist.sh
# Do not run more often than once every 5 minutes: <https://urlhaus.abuse.ch/api/#tos>

LOGFILE='unbound-update-blocklist'

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


if [ -d /tmp/tmp.updateunbound ]; then
	rm -rf /tmp/tmp.updateunbound
fi

mkdir /tmp/tmp.updateunbound
UPDATE_DIR='/tmp/tmp.updateunbound'
export UPDATE_DIR

# Make a temporary working directory to work with these files alone
cd "$UPDATE_DIR" || (echo "Failed creating temporary directory. Quitting." && echo "# [WARNING]: $(date +%Y-%m-%d) $(date +%H:%M:%S) Failed creating temporary directory." >> /var/log/"$LOGFILE" && exit)

# Download blocklists
curl -sS 'https://urlhaus.abuse.ch/downloads/hostfile/' > 'urlhaus.txt'
curl -sSLf 'https://raw.githubusercontent.com/StevenBlack/hosts/master/data/yoyo.org/hosts' > 'yoyo.txt'
# add more blocklists here

# Make sure download was successful and filetype matches what's expected
for list in ./*.txt; do
	if ! (file "$list" | grep -Eqx "^./.*\.txt:.*(ASCII text|ASCII text, with CRLF line terminators)$"); then
		echo 'One or more lists not plain text. Quitting.' 
		echo "# [WARNING]: $(date +%Y-%m-%d) $(date +%H:%M:%S) One or more lists not plain text." >> /var/log/"$LOGFILE" 
		cd ~/ || exit
		rm -rf "$UPDATE_DIR"
		exit
	fi
done

# Check for any lines not beginning with '#', 0.0.0.0, 127.0.0.1, or empty
# Do this check before parsing the file
grep -vE "^(#|0\.0\.0\.0|127\.0\.0\.1|^$)" ./*.txt >> checkerrors.out

# Parse hosts files to unbound.conf format; handles removing CRLF line terminators and empty lines
cat ./*.txt | sed '/^$/d' | sed 's/\r//g' | sed '/^#/!s/^0.0.0.0[[:space:]]//g' | sed '/^#/!s/^127.0.0.1[[:space:]]//g' | sed '/^#/!s/$[[:space:]]//g' | sed '/^#/!s/^/local-zone: "/g' | sed '/^#/!s/$/" always_nxdomain/g' > blocklist.conf

function checkFormatting() {
	# Here we want to make sure every line is properly formatted
	# Checking from the start of every line up to the url, and from the end of every url to the end of line.
	# We don't parse potentially malicious url's directly

	# Use for loops instead of ls grep, if using wildcard * filename matching in the future
	grep -v "^local-zone: \"" ./blocklist.conf | grep -v "^#" >> checkerrors.out
	grep -v "\" always_nxdomain$" ./blocklist.conf | grep -v "^#" >> checkerrors.out

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

# Automatically install the updated conf via cron, or by running manually
# Backup current blocklist and check new list to be installed for any additional errors
if [ -e '/etc/unbound/unbound.conf.d/blocklist.conf' ]; then
	mv /etc/unbound/unbound.conf.d/blocklist.conf /tmp/blocklist.conf.bkup
fi

cp ./blocklist.conf /etc/unbound/unbound.conf.d/blocklist.conf

# Specify full command path else execution fails, and use the exit code `$?` environment variable to check output
/usr/sbin/unbound-checkconf
CHECKCONF="$?"
if ! [[ "$CHECKCONF" -eq 0 ]]; then
	echo 'Error loading new blocklist, previous configuration restored. Quitting'
	echo "# [WARNING]: $(date +%Y-%m-%d) $(date +%H:%M:%S) Error loading new blocklist, previous configuration restored." >> /var/log/"$LOGFILE"
	mv /tmp/blocklist.conf.bkup /etc/unbound/unbound.conf.d/blocklist.conf
	cd ~/ || exit
	rm -rf "$UPDATE_DIR"
	exit 1
fi

systemctl restart unbound
if [ -e /tmp/blocklist.conf.bkup ]; then
	rm /tmp/blocklist.conf.bkup
fi

# Log successful installation of updated blocklist
echo "[OK]: $(date +%Y-%m-%d) $(date +%H:%M:%S) blocklist.conf" >> /var/log/"$LOGFILE"

cd ~/ || exit
rm -rf "$UPDATE_DIR"

exit
