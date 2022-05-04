# rkhunter (Rootkit Hunter)

A brief overview of running and configuring `rkhunter`

---

Behind the scenes `rkhunter` utilizes the `unhide` utilities to do the following:

- bruteforcing the entire PID space and comparing the results to tools that list system processes
- bruteforcing all 65535 TCP/UDP ports and comparing the results to tools that list listening ports and sockets
- other similar enumeration of running processes and the filesystem
	* Users, groups, account changes
	* Size of memory processes
	* Listening sockets / ports

The idea being if `unhide` cannot bind to a port or create a PID where nothing exists, there's obviously something in use of that port or PID and hidden from the kernel.

In this case, the integrity of the tools present on the current system and their ability to list and enumerate running processes and network activity is vital.

`rkhunter` achieves this by creating a database of binary signatures and other system information when initializing a database. Many of the `/sbin` and `/bin` binaries are added to this database, however it does not provide complete coverage.

You could (and should) use `aide` or a similar IDS tools in addition to `rkhunter` to gain more complete coverage.

In any case, it's recommended to save the hashes of the rkhunter data files, as well as the database file itself (`/var/lib/rkhunter/db/rkhunter.dat`) to your **password manager** or **read-only external media** immediately after install and initialization, and each time you update the database by running `rkhunter --propupd`.

```bash
sudo sha256sum /var/lib/rkhunter/db/*.dat*
```

These two files are typically the only files that will change when updating the database after it's initially setup. Back these up to your password manager and external media as well as part of the update process.

| File                                    | Description
| --------------------------------------- | ------------------------------------------------------------ |
| `/var/lib/rkhunter/db/rkhunter.dat`     | The current database file after running `rkhunter --propupd` |
| `/var/lib/rkhunter/db/rkhunter.dat.old` | The previous database file                                   |


On systems that aren't critical (ephemeral or temporary environments) saving only the hashes of the databases and configuration files alone will be enough to detect tampering.

## Basics

Install
```bash
sudo apt install -y rkhunter
```

Check your configuration file for errors after modifying it:
```bash
sudo rkhunter -C
```

Initialize a database after installing, or update a current database after running & reviewing the system:
```bash
sudo rkhunter --propupd
```

Run a check on your system
```bash
# --sk will run the entire check without requiring user interaction at each phase
sudo rkhunter --sk --check
```

Only print findings to terminal, this is less verbose, but more useful. 

Also useful when running `rkhunter` as a `cron` task:
```bash
# --rwo means 'report warnings only', and will not print anything else 
# to terminal aside from warnings or differences found with the database
sudo rkhunter --sk --check --rwo
```
