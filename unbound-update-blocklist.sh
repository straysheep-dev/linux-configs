#!/bin/bash

# Prepare the latest blocklist and check for parsing errors
# Requires manual review before installing, can be changed to run as root via cron and install automatically

# Crontab to run every 12 hours:
# 0 */12 * * * /bin/bash /opt/unbound-update-blocklist.sh
# Do not run more often than once every 5 minutes: <https://urlhaus.abuse.ch/api/#tos>

UPDATE_DIR=$(mktemp -d)
export UPDATE_DIR

# Make a temporary working directory to work with these files alone
cd "$UPDATE_DIR" || (echo "Failed to make temporary directory. Quitting." && touch ~/directory-creation.error && exit)

# Download blocklists
curl -sS 'https://urlhaus.abuse.ch/downloads/hostfile/' > 'urlhaus.txt'
curl -sSLf 'https://raw.githubusercontent.com/StevenBlack/hosts/master/data/yoyo.org/hosts' > 'yoyo.txt'

# Make sure download was successful and parse hosts format to unbound.conf format
if ! (file "${UPDATE_DIR}/*.txt" | grep -qx "^.* empty$"); then
	cat ./*.txt | sed '/^$/d' | sed 's/\r//g' | sed '/^#/!s/^0.0.0.0[[:space:]]//g' | sed '/^#/!s/^127.0.0.1[[:space:]]//g' | sed '/^#/!s/$[[:space:]]//g' | sed '/^#/!s/^/local-zone: "/g' | sed '/^#/!s/$/" always_nxdomain/g' > "$(date +%Y-%m-%d_%H:%M:%S_)"blocklist.conf
else
	(echo "One or more lists empty. Quitting." && rm -rf "$UPDATE_DIR" && touch ~/blocklist-download.error && exit)
fi
# Example filename: 2021-08-01_08:00:00_blocklist.conf

function checkErrors() {
	# Here we want to make sure every line is properly formatted
	# by checking from the start of every line up to the url, and
	# from the end of every url to the end of line, taking care to
	# not parse urls directly
	for file in ./*blocklist.conf; do
		grep -v "^local-zone: \"" "$file" | grep -v "^#" > checkerrors.out
		grep -v "\" always_nxdomain$" "$file" | grep -v "^#" >> checkerrors.out
	done

	# If every line passed the previous check, the checkerrors.out file should be empty.
	# Append .OK if it passed and .FAIL if checkerrors.out was not empty.
	if (file checkerrors.out | grep -qx "^checkerrors.out: empty$") ; then
		for file in ./*blocklist.conf; do
			touch ~/"$file".OK
		done
	else
		for file in ./*blocklist.conf; do
			touch ~/"$file".FAIL && mv "$file" -t ~/
			(echo "$file failed formatting check. Quitting." && exit)
		done
	fi
}

checkErrors

for file in ./*blocklist.conf; do
	mv "$file" -t ~/
	# Replace the above line with this line to automatically install via root cron
	#cp "$file" /etc/unbound/unbound.conf.d/
done

rm -rf "$UPDATE_DIR"

exit
