#!/bin/bash

# Summarize the system state to a logfile, readable only by root.
# Optionally make the script readable only by root.

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
# [ ] diff between daily system states

# Crontab to run every day at 12:
# 0 12 * * * /bin/bash /opt/system-summary.sh

# Export path if using `crontab -e` and not writing to /etc/crontab
# Cron does not use the expected environment variables (it's defaults are SHELL=/bin/sh && PATH=/usr/bin:/bin
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/snap/bin"

LOGFILE='system-summary'

# Root check
if [ "${EUID}" -ne 0 ]; then
	echo "You need to run this script as root"
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
	create 0640 root root
}" > /etc/logrotate.d/"$LOGFILE"
fi


# Create the log file with the correct permissions before starting
if ! [ -e /var/log/"$LOGFILE" ]; then
	touch /var/log/"$LOGFILE"
fi
chmod 640 /var/log/"$LOGFILE"

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
	echo "# [v] uid list"
	echo ''
	for user in $(cut -d":" -f1 < /etc/passwd); do id "$user" | column -t; done

	echo '#======================================================================'
	echo "# [v] groups"
	echo ''
	column -t -s ':' < /etc/group

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
	dpkg --print-architecture
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
	if (command -v mokutil); then
		mokutil --sb-state 2>&1
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
	echo '#[v] apparmor status'
	echo ''
	# to do: selinux status
	aa-status

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
	if (command -v ip); then
		ip a
	elif (command -v ifconfig); then
		ifconfig
	fi

	echo '#======================================================================'
	echo '#[v] open ports'
	echo ''
	if (command -v netstat); then
		netstat -anp -A inet,inet6
	elif (command -v ss); then
		ss -anp -A inet
	fi

	echo '#======================================================================'
	echo '#[v] firewall rules'
	echo ''
	if (command -v ufw); then
		ufw status verbose
	elif (command -v firewall-cmd); then
		echo 'to do...'
	elif (command -v iptables); then
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
		echo "/etc/hosts file contains $HOSTS_LINE_COUNT lines"
	fi

	echo '#======================================================================'
	echo "# [v] resolv.conf"
	echo ''
	cat /etc/resolv.conf

	echo '#======================================================================'
	echo "# [v] listening sockets"
	echo ''
	if (command -v netstat);then
		netstat -lnp -A unix
	elif (command -v ss); then
		ss -lnp -A unix
	fi
	
	echo '#======================================================================'
	echo "# [v] connected sockets"
	echo ''
	if (command -v netstat); then
		netstat -np -A unix
	elif (command -v ss); then
		ss -np -A unix
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
}

function filesystem() {
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
	findmnt --fstab

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
	if ! (command -v auditd); then
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
	echo '#[v] rootkit and integrity checks'
	echo ''
	if ! (command -v rkhunter); then
		echo '[!!] rkhunter not installed!'
	else
		rkhunter --sk --check --rwo
		echo ''
		echo '#[v] rkhunter database hashes'
		echo ''
		sha256sum /var/lib/rkhunter/db/rkhunter.dat*

		# We only check the compressed database and conf hashes by default, as running aide can consume 
		# system resources unless it's tuned to run regularly under cron

		echo ''
		echo '#[v] aide (compressed) database hashes'
		echo ''
		sha256sum /etc/aide/aide.conf
		sha256sum /var/lib/aide/aide.db*
	fi
}

function checkSystem() {
	echo '#==================================================================================='
	echo '###################################### BEGIN ######################################'
	echo "# System summary for $(date +%Y-%m-%d) $(date +%H:%M:%S)"

	accounts
	kernel
	hardware
	network
	processes
	services
	filesystem
	logs
	integrity

	echo "#[>] End of summary at $(date +%Y-%m-%d) $(date +%H:%M:%S)"
	echo '#==================================================================================='
	echo '####################################### END #######################################'
}
checkSystem >> /var/log/"$LOGFILE"
