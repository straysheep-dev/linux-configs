#!/bin/bash

# Prepare the latest blocklist and check for parsing errors
# Run as root via cron to install automatically or run as normal user to check manually before installing

# Crontab to run every 12 hours:
# 0 */12 * * * /bin/bash /opt/unbound-update-blocklist.sh
# Do not run more often than once every 5 minutes: <https://urlhaus.abuse.ch/api/#tos>

UID1000=$(grep '1000' /etc/passwd | cut -d ':' -f 1)

UPDATE_DIR=$(mktemp -d)
export UPDATE_DIR

# Make a temporary working directory to work with these files alone
cd "$UPDATE_DIR" || (echo "Failed to make temporary directory. Quitting." && touch /home/"$UID1000"/directory-creation.error && exit)

# Download blocklists
curl -sS 'https://urlhaus.abuse.ch/downloads/hostfile/' > 'urlhaus.txt'
curl -sSLf 'https://raw.githubusercontent.com/StevenBlack/hosts/master/data/yoyo.org/hosts' > 'yoyo.txt'

# Make sure download was successful and filetype matches what's expected
for list in ./*.txt; do
	if ! (file "$list" | grep -Eqx "^./.*\.txt:.*(ASCII text|ASCII text, with CRLF line terminators)$"); then
		(echo "One or more lists not plain text. Quitting." && touch /home/"$UID1000"/blocklist-download.error && cd ~/ && rm -rf "$UPDATE_DIR")
		exit
	fi
done

# Parse hosts files to unbound.conf format; handles removing CRLF line terminators and empty lines
cat ./*.txt | sed '/^$/d' | sed 's/\r//g' | sed '/^#/!s/^0.0.0.0[[:space:]]//g' | sed '/^#/!s/^127.0.0.1[[:space:]]//g' | sed '/^#/!s/$[[:space:]]//g' | sed '/^#/!s/^/local-zone: "/g' | sed '/^#/!s/$/" always_nxdomain/g' > "$(date +%Y-%m-%d_%H:%M:%S_)"blocklist.conf
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
			touch /home/"$UID1000"/"$file".OK
		done
	else
		for file in ./*blocklist.conf; do
			mv checkerrors.out /home/"$UID1000"/"$file".FAIL && mv "$file" /home/"$UID1000"/
		done
		echo "$file failed formatting check. Quitting."
		exit
	fi
}

checkErrors

if [ "${EUID}" -ne 0 ]; then
	for file in ./*blocklist.conf; do
		# Run as normal user, save conf file to $HOME for manual review
		mv "$file" /home/"$UID1000"/
	done
else
	for file in ./*blocklist.conf; do
		# Automatically install the updated conf via cron, or by running manually as root
		if [ -e '/etc/unbound/unbound.conf.d/blocklist.conf' ]; then
			rm /etc/unbound/unbound.conf.d/blocklist.conf
		fi
		cp "$file" /etc/unbound/unbound.conf.d/blocklist.conf
		if ! (unbound-checkconf | grep 'no errors'); then
			echo "Error with unbound configuration. Quitting."
			exit 1
		fi
		systemctl restart unbound
	done
fi

cd ~/ || exit
rm -rf "$UPDATE_DIR"

exit
