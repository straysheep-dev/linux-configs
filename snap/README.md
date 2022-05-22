# snap

Files related to the [snap package manager](https://snapcraft.io/about).

---

## snap-up.sh

Usage:

```
$ snap-up --help

NAME
       snap-up - Shell script to backup snap files created by the user

SYNOPSIS
       snap-up [OPTIONS]

DESCRIPTION
       Without any options, this will backup all non-hidden files in the latest (current) directory of each snap package.
       
       If a snap has been uninstalled the backups currently existing for it will not be deleted without -c|--clean.

       Specifically it looks under: /home/$USERNAME/snap/<package> for /home/$USERNAME/snap/<package>/current/<files>
       to backup <files> to: /home/$USERNAME/snap/backups/<package>/<date/time><file>

       Example: /home/ubuntu/snap/chromium/current/example.data  ->  /home/ubuntu/snap/backups/chromium/2022-05-01_11:22:33_example.data
       Example: /home/ubuntu/snap/gedit/current/file with spaces.txt  ->  /home/ubuntu/snap/backups/gedit/2022-05-01_11:22:33_file_with_spaces.txt

       ~/snap/backups is used because snaps cannot read from other snap directories, even with the "home" connection.

OPTIONS
    -c, --clean
       Clean allows you to empty the backup directory located in "/home/$USERNAME/snaps/backups". Considered dangerous, the operation has two prompts for
       confirmation before doing anything. This is typically run after backing up the latest files to external media or cloud storage to save disk space.

    -l, --list
       Print an easily readable list of all currently backed up files in "/home/$USERNAME/snaps/backups". This will also check if the environment variable 
       SET_SYNC_PATH has a path, and read from there as well.

    -s, --sync
       The sync option will let you specify a path to rsync the "/home/$USERNAME/snaps/backups" directory to. This can be run multiple times with the 
       same sync location, and rsync automatically updates only what was changed, added, or removed from the source "/home/$USERNAME/snaps/backups" folder.
       
       If you wanted to automate this, you can export the sync arguments as environment variables. The script will walk through prompts to do this for you.
       
       export SYNC_CHOICE="y"
       export SET_SYNC_PATH="/tmp"
       snap-up -s
       
       Add them to bashrc for persistence.
       Running with the -s|--sync switch will automatically sync to the target folder. Remove the environment variables interactively with:
       
       unset SYNC_CHOICE
       unset SET_SYNC_PATH
       or
       export SYNC_CHOICE=""
       export SET_SYNC_PATH=""
       
       or remove the lines from ~/.bashrc

    -t, --test
       Perform a test run without making any changes. This will show all discovered files to be backed up, and their destination.
```
