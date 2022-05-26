#!/bin/bash

# Summarize the system state to a logfile, readable only by root.

# To do:
# [x] filesystem io
#	see `sar` and `iostat`
#	sudo apt install -y sysstat
# [x] unix sockets
# [ ] mail server checks
# [ ] webserver checks
# [ ] fedora / bsd compatibility
# [ ] selinux / tripwire / other security checks
# [ ] auth / pam / other log checks
# [/] diff between daily system states

# Crontab to run every day at 12:
# 0 12 * * * /bin/bash /opt/system-summary.sh

# Export path if using `crontab -e` and not writing to /etc/crontab
# Cron does not use the expected environment variables (it's defaults are SHELL=/bin/sh && PATH=/usr/bin:/bin
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/snap/bin"

LOGNAME='system-summary'
LOGFILE='system-summary.log'

# Root check
if [ "${EUID}" -ne 0 ]; then
	echo "You need to run this script as root"
	exit 1
fi


# Create the logging configuration if it doesn't exist
if ! [ -e /etc/logrotate.d/"$LOGNAME" ]; then
	echo "# Logging configuration for $LOGNAME shell script
/var/log/$LOGNAME/$LOGFILE {
	nocompress
	weekly
	rotate 7
	missingok
	notifempty
	su root root
	create 0640 root root
}" > /etc/logrotate.d/"$LOGNAME"
fi


# Create the log file and directory with the correct permissions before starting
if ! [ -e /var/log/"$LOGNAME" ]; then
	mkdir /var/log/"$LOGNAME" || exit 1
fi
if ! [ -e /var/log/"$LOGNAME"/"$LOGFILE" ]; then
	touch /var/log/"$LOGNAME"/"$LOGFILE" || exit 1
fi
chmod 755 /var/log/"$LOGNAME" || exit 1
chmod 640 /var/log/"$LOGNAME"/"$LOGFILE" || exit 1

function accounts() {
	echo '#======================================================================'
	echo '#[v] active sessions'
	echo ''
	w

	echo '#======================================================================'
	echo "# [v] login history"
	echo ''
	last -a

	echo '#======================================================================'
	echo "# [v] users"
	echo ''
	column -t -s ':' < /etc/passwd | sort -k 3 -n

	echo '#======================================================================'
	echo "# [v] groups"
	echo ''
	column -t -s ':' < /etc/group | sort

	echo '#======================================================================'
	echo '#[v] environemnt'
	echo ''
	env
}

function kernel() {
	echo '#======================================================================'
	echo "# [v] kernel"
	echo ''
	uname -mrs
	if (command -v dpkg > /dev/null); then
		dpkg --print-architecture
	fi
	cat /proc/version

	echo '#======================================================================'
	echo '#[v] kernel integrity'
	echo ''
	if [ -e /sys/kernel/security/lockdown ]; then
		cat /sys/kernel/security/lockdown
	fi

	echo '#======================================================================'
	echo '#[v] secureboot'
	echo ''
	if (command -v mokutil > /dev/null); then
		if (mokutil --sb-state 2>&1); then
			echo ''
			# Summarize all currently enrolled keys
			mokutil --list-enrolled | grep -A 1 -P "^(\[key\s\d\]|SHA1\sFingerprint:\s[\w\w:]{59}|\s+Issuer:\s|\s+Subject:\s|\s+X509v3\s(Basic\sConstraints:|Extended\sKey\sUsage:))" | grep -Pv "^(\-\-|\s+Validity$|\s+Subject\sPublic\sKey\sInfo:$|Certificate:$)"
		fi
	fi

	echo '#======================================================================'
	echo "# [v] critical kernel parameters"
	echo ''
	if ! (sysctl -a | grep -E "^fs.protected_hardlinks = 1$"); then
		echo "[WARNING]fs.protected_hardlinks != 1"
	fi
	if ! (sysctl -a | grep -E "^fs.protected_symlinks = 1$"); then
		echo "[WARNING]fs.protected_symlinks != 1"
	fi
	if ! (sysctl -a | grep -E "^fs.suid_dumpable = 0$"); then
		echo "[WARNING]fs.suid_dumpable != 0"
	fi
	if ! (sysctl -a | grep -E "^kernel.randomize_va_space = 2$"); then
		echo "[WARNING]kernel.randomize_va_space != 2"
	fi
	if ! (sysctl -a | grep -E "^kernel.sysrq = 0$"); then
		echo "[WARNING]kernel.sysrq != 0"
	fi

	echo '#======================================================================'
	echo "# [v] cpu vulnerabilities"
	echo ''
	head -n -0 /sys/devices/system/cpu/vulnerabilities/*

	echo '#======================================================================'
	echo '#[v] mac status'
	echo ''
	if (command -v aa-status > /dev/null); then
		aa-status
	elif (command -v sestatus > /dev/null); then
		sestatus
	fi

	echo '#======================================================================'
	echo "# [v] loaded kernel modules"
	echo ''
	lsmod | sort
}

function hardware() {
	echo '#======================================================================'
	echo "# [v] hardware"
	echo ''
	lshw -sanitize -short

	echo '#======================================================================'
	echo "# [v] pci devices"
	echo ''
	lspci

	echo '#======================================================================'
	echo "# [v] usb devices"
	echo ''
	lsusb
}

function network() {
	echo '#======================================================================'
	echo '#[v] hostname'
	echo ''
	hostname

	echo '#======================================================================'
	echo '#[v] arp table'
	echo ''
	arp -e

	echo '#======================================================================'
	echo '#[v] routing table'
	echo ''
	route -n

	echo '#======================================================================'
	echo '#[v] network interfaces'
	echo ''
	if (command -v ip > /dev/null); then
		ip a
	elif (command -v ifconfig > /dev/null); then
		ifconfig
	fi

	echo '#======================================================================'
	echo '#[v] open ports'
	echo ''
	if (command -v netstat > /dev/null); then
		netstat -anp -A inet,inet6
	elif (command -v ss > /dev/null); then
		ss -anp -A inet
	fi

	echo '#======================================================================'
	echo '#[v] firewall rules'
	echo ''
	if (command -v ufw > /dev/null); then
		ufw status verbose
	elif (command -v firewall-cmd > /dev/null); then
		echo 'to do...'
	elif (command -v iptables > /dev/null); then
		iptables -n -L -v
		ip6tables -n -L -v
	fi

	echo '#======================================================================'
	echo '#[v] packet forwarding'
	echo ''
	ls -l /proc/sys/net/ipv4/ip_forward
	cat /proc/sys/net/ipv4/ip_forward
	ls -l /proc/sys/net/ipv6/conf/all/forwarding
	cat /proc/sys/net/ipv6/conf/all/forwarding

	echo '#======================================================================'
	echo "# [v] hosts file"
	echo ''

	HOSTS_LINE_COUNT="$(wc -l /etc/hosts | cut -d ' ' -f 1)"

	if [ "$HOSTS_LINE_COUNT" -gt 50 ]; then
		head -n 50 /etc/hosts
		echo "..."
		echo "/etc/hosts file contains $HOSTS_LINE_COUNT lines"
	else
		cat /etc/hosts
		echo ''
		echo "/etc/hosts file contains $HOSTS_LINE_COUNT lines"
	fi

	echo '#======================================================================'
	echo "# [v] resolv.conf"
	echo ''
	cat /etc/resolv.conf

	echo '#======================================================================'
	echo "# [v] listening sockets"
	echo ''
	if (command -v netstat > /dev/null);then
		netstat -lnp -A unix
	elif (command -v ss > /dev/null); then
		ss -lnp -A unix
	fi
	
	echo '#======================================================================'
	echo "# [v] connected sockets"
	echo ''
	if (command -v netstat > /dev/null); then
		netstat -np -A unix
	elif (command -v ss > /dev/null); then
		ss -np -A unix
	fi
	
	echo '#======================================================================'
	echo "# [v] d-bus"
	echo ''
	if (command -v busctl > /dev/null); then
		busctl list
	fi
}

function processes() {
	echo '#======================================================================'
	echo '#[v] process tree'
	echo ''
	ps axjf
}

function services() {
	echo '#======================================================================'
	echo '#[v] timers'
	echo ''
	systemctl list-timers --all

	echo '#======================================================================'
	echo '#[v] crontabs'
	echo ''
	cat /etc/crontab

	for crontab in /var/spool/cron/crontabs/* ; do
		echo '#======================================================================'
		echo "#[v] $crontab"
		echo ''
		cat "$crontab"
	done

	echo '#======================================================================'
	echo '#[v] cron.d'
	echo ''
	for file in /etc/cron.d/*; do echo "$file"; done

	echo '#======================================================================'
	echo '#[v] cron.hourly'
	echo ''
	for file in /etc/cron.hourly/*; do echo "$file"; done

	echo '#======================================================================'
	echo '#[v] cron.daily'
	echo ''
	for file in /etc/cron.daily/*; do echo "$file"; done

	echo '#======================================================================'
	echo '#[v] cron.weekly'
	echo ''
	for file in /etc/cron.weekly/*; do echo "$file"; done

	echo '#======================================================================'
	echo '#[v] cron.monthly'
	echo ''
	for file in /etc/cron.monthly/*; do echo "$file"; done
}

function filesystem() {
	echo '#======================================================================'
	echo "# [v] sandbox permissions table"
	echo ''
	if (command -v flatpak > /dev/null); then
		flatpak permissions
	fi

	echo '#======================================================================'
	echo "# [v] capabilities"
	echo ''
	getcap -r / 2>/dev/null

	echo '#======================================================================'
	echo "# [v] suid bins"
	echo ''
	find / -perm -u=s -type f -ls 2>/dev/null

	echo '#======================================================================'
	echo "# [v] sgid bins"
	echo ''
	find / -perm -g=s -type f -ls 2>/dev/null

	echo '#======================================================================'
	echo "# [v] /etc files modified in the last 24 hours"
	echo ''
	find /etc/ -type f -mtime 0 -ls 2>/dev/null

	echo '#======================================================================'
	echo '#[v] temporary files modified within 24 hours'
	echo ''
	find /tmp -mtime 0 -ls 2>/dev/null
	find /var/tmp -mtime 0 -ls 2>/dev/null
	find /dev/shm -mtime 0 -ls 2>/dev/null

	echo '#======================================================================'
	echo "# [v] /root files modified within 24 hours"
	echo ''
	find /root -mtime 0 -ls 2>/dev/null

	echo '#======================================================================'
	echo '#[v] authorized ssh keys'
	echo ''
	echo '#/root/.ssh/authorized_keys'
	find /root -type f -name "authorized_keys" -print0 | xargs -0 cat
	echo ''
	echo '#/home/*/.ssh/authorized_keys'
	find /home -type f -name "authorized_keys" -print0 | xargs -0 cat

	echo '#======================================================================'
	echo '#[v] authorized_keys modified within 24 hours'
	echo ''
	find /home -name "authorized_keys" -mtime 0 -ls 2>/dev/null

	echo '#======================================================================'
	echo '#[v] world-writable && executable folders'
	echo ''
	find / \( -perm -o=w -perm -o=x \) -type d -ls 2>/dev/null
	echo '#======================================================================'
	echo '#[v] world-writable files'
	echo ''
	find / -type f \( -perm -0002 -a \! -perm -1000 \) -ls 2>/dev/null | grep -Ev "(/proc|/sys)"
	echo '#======================================================================'
	echo '#[v] no-owner files'
	echo ''
	find / \( -nouser -o -nogroup \) -ls 2>/dev/null

	echo '#======================================================================'
	echo '#[v] fs mounts'
	echo ''
	findmnt -R

	echo '#======================================================================'
	echo '#[v] disk-usage'
	echo ''
	du -h -d 1 / 2>/dev/null
	echo ''
	df -h

	echo '#======================================================================'
	echo '#[v] io stats'
	echo ''
	vmstat -a -w
	echo ''
	vmstat -a -w -d
	echo ''

	echo '#======================================================================'
	echo '#[v] memory io'
	echo ''
	vmstat -a -w -s
	echo ''

	echo '#======================================================================'
	echo '#[v] disk io'
	echo ''
	vmstat -a -w -D
}

function logs() {
	echo '#======================================================================'
	echo '#[v] auditd summary'
	if ! (command -v auditd > /dev/null); then
		echo '[!!]auditd not installed!'
	else
		# --input-logs required when running auditd utils from cron
		aureport --input-logs -ts yesterday -i --summary
		sleep 2
		aureport --input-logs -ts yesterday -i -l --success
		sleep 2
		aureport --input-logs -ts yesterday -i -k --summary

		echo '#======================================================================'
		echo '#[v] active rules'
		echo ''
		auditctl -l

		# Use the following two entries as templates to check keys specific to
		# your environment
		echo '#======================================================================'
		echo '#[v] suspicious bin usage'
		echo ''
		ausearch --input-logs -ts yesterday -i -l -k susp_activity | grep 'proctitle=' | sed 's/^.*proctitle=/proctitle=/g' | sort | uniq -c | sort -nr
		sleep 2

		echo '#======================================================================'
		echo '#[v] elevated command execution'
		echo ''
		ausearch --input-logs -ts yesterday -i -l -k T1548.003_Sudo_and_Sudo_Caching | grep 'proctitle=' | sed 's/^.*proctitle=/proctitle=/g' | sort | uniq -c | sort -nr
		sleep 2
	fi

	echo '#======================================================================'
	echo '#[v] dns query replies'
	echo ''
	grep 'unbound' /var/log/syslog | grep -E "(([0-9]{1,3}\.){3}([0-9]{1,3}))" | sed 's/^.*info: //g' | grep -v 'NXDOMAIN' | cut -d ' ' -f 1-2 | sort | uniq -c | sort -k 2 -nr

	echo '#======================================================================'
	echo '#[v] blocked domains'
	echo ''
	grep 'unbound' /var/log/syslog | grep -E "(([0-9]{1,3}\.){3}([0-9]{1,3}))" | sed 's/^.*info: //g' | grep 'NXDOMAIN' | cut -d ' ' -f 1-2 | sort | uniq -c | sort -k 2 -nr

	echo '#======================================================================'
	echo '#[v] latest package updates'
	echo ''
	grep ' installed ' /var/log/dpkg.log
}

function integrity() {
	echo '#======================================================================'
	if ! (command -v rkhunter > /dev/null); then
		echo '[!!] rkhunter not installed!'
		echo ''
	else
		echo '#[v] rootkit checks'
		echo ''
		rkhunter --sk --check --rwo
		echo ''
		echo '#======================================================================'
		echo '#[v] rkhunter database hashes'
		echo ''
		sha256sum /var/lib/rkhunter/db/rkhunter.dat*
		echo ''
	fi

	if ! (command -v aide > /dev/null); then
		echo '[!!] aide not installed!'
		echo ''
	else
		echo '#======================================================================'
		echo '#[v] system integrity checks'
		echo ''
		aide -c /etc/aide/aide.conf -C
		echo ''
		echo '#======================================================================'
		echo '#[v] aide (compressed) database hashes'
		echo ''
		sha256sum /etc/aide/aide.conf
		sha256sum /var/lib/aide/aide.db*
		echo ''
	fi
}

function changes() {

if ! [ -e /var/log/"$LOGNAME"/system-changes ]; then
	mkdir /var/log/"$LOGNAME"/system-changes
	chmod 755 /var/log/"$LOGNAME"/system-changes
fi

if [ -e /var/log/"$LOGNAME"/"$LOGFILE".1 ]; then
	diff /var/log/"$LOGNAME"/"$LOGFILE".1 /var/log/"$LOGNAME"/"$LOGFILE" > /var/log/"$LOGNAME"/system-changes/"$(date +%F_%T)"_system-changes.diff
	chmod 640 /var/log/"$LOGNAME"/system-changes/*
fi

}

function checkSystem() {
	echo '#==================================================================================='
	echo '###################################### BEGIN ######################################'
	echo "# System summary for $(date +%F\ %T)"

	accounts
	kernel
	hardware
	network
	processes
	services
	filesystem
	logs
	integrity
	changes

	echo "#[>] End of summary at $(date +%F\ %T)"
	echo '#==================================================================================='
	echo '####################################### END #######################################'
}
checkSystem | tee /var/log/"$LOGNAME"/"$LOGFILE"
