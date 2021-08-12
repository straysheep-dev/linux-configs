#!/bin/bash

# Prepare the latest blocklist and check for parsing errors
# Requires manual review before installing, can be changed to run as root via cron and install automatically

# Crontab to run every 12 hours:
# 0 */12 * * * /bin/bash /opt/unbound-update-blocklist.sh
# Do not run more often than once every 5 minutes: <https://urlhaus.abuse.ch/api/> <https://urlhaus.abuse.ch/api/#tos>

# Regex for the blocklist's filename to avoid wildcards
FILENAME="([0-9]{4,4}-[0-9]{2,2}-[0-9]{2,2}_[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2})_blocklist.conf"

export UPDATE_DIR=$(mktemp -d)
cd "$UPDATE_DIR"

curl -sS 'https://urlhaus.abuse.ch/downloads/hostfile/' > 'urlhaus.txt'
curl -sSLf 'https://raw.githubusercontent.com/StevenBlack/hosts/master/data/yoyo.org/hosts' > 'yoyo.txt'

cat *.txt | sed '/^$/d' | sed 's/\r//g' | sed '/^#/!s/^0.0.0.0[[:space:]]//g' | sed '/^#/!s/^127.0.0.1[[:space:]]//g' | sed '/^#/!s/$[[:space:]]//g' | sed '/^#/!s/^/local-zone: "/g' | sed '/^#/!s/$/" always_nxdomain/g' > "$(date +%Y-%m-%d_%H:%M:%S_)"blocklist.conf

# Example filename: 2021-08-01_08:00:00_blocklist.conf

function checkErrors() {
    cat $(ls | grep -o -E "${FILENAME}") | grep -v "^local-zone: \"" | grep -v "^#" > checkerrors.out
    cat $(ls | grep -o -E "${FILENAME}") | grep -v "\" always_nxdomain$" | grep -v "^#" >> checkerrors.out

    if (file checkerrors.out | grep -qx "^checkerrors.out: empty$") ; then
        touch $(ls | grep -o -E "${FILENAME}").OK
    else
        touch $(ls | grep -o -E "${FILENAME}").FAIL
    fi
}

checkErrors

# (OK|FAIL) needs moved first to avoid issue with mv
# mv: cannot stat 'xxxx-xx-xx_xx:xx:xx_blocklist.conf': No such file or directory
mv $(ls | grep -o -E "${FILENAME}"."(OK|FAIL)") -t ~/
mv $(ls | grep -o -E "${FILENAME}") -t ~/

rm -rf "$UPDATE_DIR"
