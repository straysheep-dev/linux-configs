# AIDE (Advanced Intrusion Detection Environment)

How to setup `aide` for filesystem integrity monitoring and do basic tuning of the configuration.

## License Information

`aide` is licensed under the GPL-2.0 license.

<https://github.com/aide/aide/blob/master/COPYING>

## References

- `man aide.conf`
- <https://aide.github.io/>
- <https://aide.github.io/doc>
- The following shows good examples of writing configurations:
	* <https://github.com/openshift/file-integrity-operator/blob/master/aide.conf.rhel8>

## Setup

Install
```bash
sudo apt install -y aide
```

You may want to write your own cron task instead of the default which will execute daily:
```bash
sudo chmod -x /etc/cron.daily/aide
```

## Quick Usage

You can do this with any attribute you are monitoring. See the `summarize_changes` section under `man aide.conf` for the list of attributes (which are individual letters).

When you run a check with `sudo -c </path/to/aide.conf> -C` and are summarizing changes, summary lines under `Changed entries:` are printed like this:

```
# your results will look slightly different
d = ... .. .. .: /path/to/example/directory1
f = ... .. .. .: /path/to/example/file1
```

Those `.` dots will be replaced with the letter of the attribute, if it differs from what's stored in your current database.

This command will only return files where the checksum(s) `C` (Aide 0.16.1) or message digests `H` (Aide 0.17.4) have changed, filtering out any results under `/etc/vmware-installer/`.
```bash
sudo -c </path/to/aide.conf> -C | grep -P "<attribute(s)-to-check>" | grep -Fv "<results-to-filter>"
sudo -c /etc/aide/aide.conf -C | grep -P "^f (<|>|=) ........(C|H)" | grep -Fv "/etc/vmware-installer/"
```

### Configuring `aide`

- Backup the default conf file: `sudo cp -n /etc/aide/aide.conf{,.bkup}`
- Make any changes to the configuration `sudo nano /etc/aide/aide.conf`
- You may want to replace this file entirely with your own
- Note that this file often `@@include`'s additional files contained within `/etc/aide/aide.conf.d/`, `/etc/aide/aide.settings.d/`, and `/etc/default/aide`
- See `man aide.conf` for details on `MACRO LINES`
- What the example configurations in this repo do:
	* Comment out all `@@include` lines
	* Append group definitions (`FULL` and `LOGS`) with all of the attributes we may want to monitor
	* Append a list of all directories or files we may want to monitor
	* The goal being fast database processing (~60s or less), and a brief, easy to read configuration
		- Using `aide` in addition to `auditd` and `rkhunter` or similar tools can provide greater coverage without increasing processing time


Initialize the database, specifying the configuration file to use with `-c`:
```bash
sudo aide --init -c /etc/aide/aide.conf
```

Be sure to copy the entire result that's printed to terminal, the configuration file, and the database file itself, to either your **password manager**, or **read-only external media**.

On systems that aren't critical (ephemeral or temporary environments) saving only the hashes of the databases and configuration files alone will be enough to detect tampering.

Next, 'install' the new database by copyying it from the `db.new` path where it's written, to the `.db` path listed in the .conf file.

```bash
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

Examples of these lines specifying the database paths:

```
# /etc/aide/aide.conf
# aide version 0.16.1
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
database_new=file:/var/lib/aide/aide.db.new
```

```
# /etc/aide/aide.conf
# aide version 0.17.3
database_in=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
database_new=file:/var/lib/aide/aide.db.new
```

You could change those paths to point to a database on read-only / external media.

---

Check the integrity of the system using a specified config file:
```bash
sudo aide -c /etc/aide/aide.conf -C
```

When it's time to update the database to a new state, after system changes have been made and reviewed:
```bash
# writes an updated database to the path specfied in 'database_new=' in your configuration file
sudo aide -u -c /etc/aide/aide.conf

# install the new database by copying the .db.new file onto the .db file
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### Rule Writing

You can always add or modify files in the `/etc/aide/aide.conf.d/`, or any path mentioned as an `@@include` in the main configuration file.

These files are similar to `auditd` rule files.

For example `/etc/aide/aide.conf.d/31_aide_home_directories` might contain the following lines:

```
!/home/user/Desktop/                               # Exclude all under ~/Desktop
!/home/user/Documents/file-changes-often$          # Exclude a single file or folder
VAR = sha256                                       # Create a group definition to monitor only the sha256 attribute
VAR2 = l+b+p                                       # Create a group definition to monitor link name, block count, and permission attributes
/home/user/Documents/include-this-file$ VAR        # Include a single file or folder with attributes defined by VAR to monitor
/home/user/Documents/spaces%20need%20escaped%20    # Escape special characters in file and folder names with two-digit URL encoding, see `man URL`
```

---

### aide.wrapper

Ubuntu has the shell scripts `/usr/bin/aide.wrapper` and `/usr/sbin/aideinit` to call aide functions.

If you'd like to use these instead, do the same as you would to modify the configuration file(s) as needed. However, Ubuntu's aide package also includes a script `/usr/sbin/update-aide.conf`.

You can see what files this script is reading from to generate a new configuration by reading the top of the shell script `less -S /usr/sbin/update-aide.conf`.

This generates a full configuration file based on the previously mentioned directories, and writes this file to `/var/lib/aide/aide.conf.autogenerated`

Both `aideinit` and `aide.wrapper` then reads the configuration from that location when they're executed, **if** an alternate config file isn't provided on the commandline with `-c` or `--config`.

If either script cannot find the config file provided by `-c` or `--config`, or if `/var/lib/aide/aide.conf.autogenerated` doesn't exist, both scripts automatically call `/usr/sbin/update-aide.conf` to generate one.

Setup `aide` in one line using these scripts:
```bash
sudo update-aide.conf && sudo aideinit && sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

---
