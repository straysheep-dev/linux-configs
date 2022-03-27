#!/bin/bash

# Automated retieval and sync of remote logs to central log server
# Done without needed to manage or setup syslog on every logging endpoint
# Portable script, works on any machine with bash, rsync, and cron locally available.
# Easily manage sync rate and commands with cron.

# To schedule various cron tasks for different log types or systems, it's easy to create separate files under /etc/cron.d/
# The example below syncs logs every 5 minutes, run as $USERNAME (which you would replace with your username, ideally not root.)

# # /etc/cron.d/logsync-zeek: crontab entries to sync remote Zeek logs to a central logging system.
# SHELL=/bin/bash
# PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
# */5 *   * * *   $USERNAME  /bin/bash /opt/scripts/logsync-zeek.sh

# You'll want to look at how frequently logs are written, and how they're written, to determine the most efficient way to sync them.
# For example Zeek logs rotate every hour, and are written at the start of the current hour for the duration of that hour.
# Filename format: dns.00:00:00-01:00:00.log.gz
# Knowing this, your RPATH could be "/usr/local/logs/$(date +\%Y-\%m-\%d)/"
# and your RLOG_NAME could be "*\.$(date +\%H):00:00-$(date -d '+1 hour' +\%H:)00:00\.log\.gz"
# A good way to test this is passing the command to ssh, with ls to see if your shell interprets the regex correctly:
# ssh user@fe80::1234:aaaa:1234:abcd%eth0 ls "/usr/local/logs/$(date +\%Y-\%m-\%d)/*\.$(date +\%H):00:00-$(date -d '+1 hour' +\%H:)00:00\.log\.gz"
# You will also likely need to modify one or more filenames with the 'date' command using the -d switch if the target system follows a different
# timezone than your local system.

# TO DO:
# for loop through list of remote hosts

# <https://unix.stackexchange.com/questions/19804/compress-a-directory-using-tar-gz-over-ssh-to-local-computer>

# Use ssh + stdout + tar + shell redirection to avoid scp -r mishandling symlinks, utilize compression for file transfer, all across remote machines without needing to setup rsync daemons.
# Example one-line: ssh user@fe80::1234:aaaa:1234:abcd%eth0 'cd /usr/local/logs && tar -czf - ./2022-*' > /home/user/Documents/zeek-$(date +\%Y-\%m-\%d).tar.gz

RUSER='remote_username_used_for_ssh'
RHOST='remote_hostname_or_ip'
RPATH="remote_path_to_retreive_logs_from"
RLOG_NAME="name_of_remote_log_files_or_dirs_can_be_regex"
LPATH="local_path_to_save_remote_logs_to"
LLOG_NAME="name_of_local_dir_to_contain_these_logs"
TMP_PATH="local_path_for_staging_local_only_rsync_of_recently_retrieved_logs"

if ! [ -e "$LPATH/$LLOG_NAME/$(date +\%Y-%m-%d).tar.gz" ]; then
    # If $LLOG_NAME does not exist (ie; you modified or duplicated this script to gather different log types) create a directory for it
    echo "Gathering remote log files..."
    mkdir "$LPATH"/"$LLOG_NAME"
    cd "$LPATH"/"$LLOG_NAME" || exit 1
    ssh $RUSER@"$RHOST" "cd $RPATH && tar -czf - $RLOG_NAME" > "$LPATH"/"$LLOG_NAME"/$(date +\%Y-\%m-\%d).tar.gz && \
    tar -xzf ./$(date +\%Y-\%m-\%d).tar.gz
    echo "Done."
elif [ -e "$LPATH/"$LLOG_NAME"/$(date +\%Y-%m-%d).tar.gz" ]; then
    # Check for existing logs, if found, save the latest archive to a temp folder, and rsync the difference locally
    echo "Syncing local log archives with remote sources..."
    mkdir "$TMP_PATH"/tmp
    cd "$TMP_PATH"/tmp || exit 1
    ssh $RUSER@"$RHOST" "cd $RPATH && tar -czf - $RLOG_NAME" > "$TMP_PATH"/tmp/$(date +\%Y-\%m-\%d).tar.gz && \
    tar -xzf ./$(date +\%Y-\%m-\%d).tar.gz
    rsync -rv "$TMP_PATH"/tmp/ "$LPATH"/"$LLOG_NAME"
    echo "Done."
    cd / && rm -rf "$TMP_PATH"/tmp
fi
