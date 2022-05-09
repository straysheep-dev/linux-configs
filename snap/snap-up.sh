#!/bin/bash

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

# Without any options, this will backup all non-hidden files in the latest (current) directory of each snap package
# This typically includes data or configurations that need saved and backed up
# This script ignores all hidden files and folders
# The default backup location is ~/snap/backups
# This is because snaps cannot read from other snap directories, even with the 'home' connection.

# Check if we're running with root or sudo, and exit if we are.
if [ "$EUID" == '0' ]; then
	echo "Run as a normal user instead of root. Quitting."
	exit 1
fi

function SnapUp() {
	# Create the backup directory if it does not exist
	if ! [ -d /home/"$USERNAME"/snap/backups ]; then
		echo ""
		echo "[i]Creating /home/$USERNAME/snap/backups..."
		mkdir /home/"$USERNAME"/snap/backups
	fi

	echo -e "[${BLUE}>${RESET}]Starting $(date +%F%T)..."

	# Filter out the backups folder as well as any folder names with spaces
	# Usernames should not have spaces (IEEE Std 1003.1-2001)
	# Snap packages only use '-' dashes in package names
	# This find operation would result in word splitting if spaces were in the folder path
	# https://www.shellcheck.net/wiki/SC2086
	FIND_SNAPS="$(find /home/"$USERNAME"/snap/* -maxdepth 0 -type d ! -name "backups" ! -name "* *")"

	for folder in $FIND_SNAPS; do

		# Create a backup folder for each snap package installed
		if ! [ -d /home/"$USERNAME"/snap/backups/"$(basename "$folder")" ]; then
			mkdir /home/"$USERNAME"/snap/backups/"$(basename "$folder")"
		fi

		for file in "$folder"/current/*.*; do

			# We take the path and parse out the snap name, and the file name (5,7)
			# ie; /home/ubuntu/snap/firefox/current/user.js -> firefox/user.js
			# when using cut with the delimiter of '/', 'firefox' is 5th, and 'user.js' is 7th
			# find "$folder"/current/ -maxdepth 1 -type f ! -name "\.*" -ls | rev | cut -d ' ' -f 1 | rev | cut -d '/' -f 5,7

			TARGET_FILE="$(echo "$file" | rev | cut -d ' ' -f 1 | rev | cut -d '/' -f 7)"
			TARGET_DIR="$(echo "$file" | rev | cut -d ' ' -f 1 | rev | cut -d '/' -f 5)"

			# If the directory is empty, it will return '*.*' as the filename
			if (echo "$TARGET_FILE" | grep -qx '\*\.\*'); then
				echo -e "${BLUE}[EMPTY]${RESET}: $folder" | column -t
			# Rename files with spaces in their names to avoid word splitting
			elif (echo "$file" | grep -q ' '); then
				echo -e "${YELLOW}[RENAME]${RESET}::$file" | sed 's/ \+/_/g' | sed 's/::/: /'
				mv "$file" "$(echo "$file" | sed 's/ \+/_/g')"
			else
				# Copy each file to it's snap backup folder, prefixing the filename with the date and time
				# This prevents overwriting backups
				echo "[BACKUP]: $file -> /home/$USERNAME/snap/backups/$TARGET_DIR/$(date +%F_%T)_$TARGET_FILE" | column -t
				cp "$file" /home/"$USERNAME"/snap/backups/"$TARGET_DIR"/"$(date +%F_%T)"_"$TARGET_FILE"
			fi

		done

	done
	
	echo -e "[${GREEN}✓${RESET}]Done. $(date +%F%T)"
	
	exit 0
}

function TestRun() {

	echo "[TEST]: NO CHANGES MADE, SHOWING DISCOVERED FILES, FILES TO RENAME, AND BACKUP DESTINATIONS."

	FIND_SNAPS="$(find /home/"$USERNAME"/snap/* -maxdepth 0 -type d ! -name "backups" ! -name "* *")"

	for folder in $FIND_SNAPS; do

		for file in "$folder"/current/*.*; do

			TARGET_FILE="$(echo "$file" | rev | cut -d ' ' -f 1 | rev | cut -d '/' -f 7)"
			TARGET_DIR="$(echo "$file" | rev | cut -d ' ' -f 1 | rev | cut -d '/' -f 5)"

			# If the directory is empty, it will return '*.*' as the filename
			if (echo "$TARGET_FILE" | grep -qx '\*\.\*'); then
				echo -e "${BLUE}[EMPTY]${RESET}: $folder" | column -t
			# Show what files with spaces in their names will be renamed to
			elif (echo "$file" | grep -q ' '); then
				echo -e "${YELLOW}[RENAME]${RESET}::$file" | sed 's/ \+/_/g' | sed 's/::/: /'
			else
				# Else show all discovered files to backup, and their destination path
				echo "[TEST]: $file -> /home/$USERNAME/snap/backups/$TARGET_DIR/$(date +%F_%T)_$TARGET_FILE" | column -t
			fi
		done

	done

	echo "[TEST]: NO CHANGES MADE, SHOWING DISCOVERED FILES, FILES TO RENAME, AND BACKUP DESTINATIONS."

}

function SyncUp() {
	if [ "$SYNC_CHOICE" == "" ]; then
		echo ""
		echo "Sync your backup folder to another directory?"
		echo ""
		until [[ $SYNC_CHOICE =~ ^(y|n)$ ]]; do
			read -rp "[y/n]: " SYNC_CHOICE
		done
	fi

	if [ "$SYNC_CHOICE" == "n" ]; then
		echo ""
		exit 0

	elif [ "$SYNC_CHOICE" == "y" ]; then
		echo ""
		echo "You do not need to include 'backups/' in your path, it's created automatically."
		echo ""
		until [[ $SET_SYNC_PATH =~ ^(/[a-zA-Z0-9_-]+){1,}$ ]]; do
			read -rp "[FULL PATH]: " SET_SYNC_PATH
		done
	else
		exit 1
	fi
	
	if ! [ "$SET_SYNC_PATH" == "" ]; then

		# Create the sync path if it does not exist
		if ! [ -d "$SET_SYNC_PATH" ]; then
			echo "[i]Creating path..."
			mkdir -p "$SET_SYNC_PATH"
		fi
		
		# This check is in case you've run snap-up with -c|--clean and are about to run -s|--sync
		# In that case, this operation would delete anything in the destination sync folder that is not in the source backup folder
		if (diff /home/"$USERNAME"/snap/backups/ "$SET_SYNC_PATH"/backups/ -r 2>/dev/null | grep -P "Only in $SET_SYNC_PATH/backups"); then
			echo ""
			echo -e "${YELLOW}[WARNING]${RESET}: This operation will modify or delete items that only exist in $SET_SYNC_PATH/backups"
			echo ""
			until [[ $SYNC_CONFIRM =~ ^(y|n)$ ]]; do
				read -rp "Continue? [y/n]: " SYNC_CONFIRM
			done
			
			if [ "$SYNC_CONFIRM" == "n" ]; then
				echo "Quitting."
				exit 0
			fi
		fi
		
		echo ""
		echo "[EXEC]: $ rsync -arv --delete /home/$USERNAME/snap/backups $SET_SYNC_PATH"
		echo ""
		sleep 1
		echo -e "[${BLUE}>${RESET}] Syncing to -> $SET_SYNC_PATH" 
		rsync -arv --delete /home/"$USERNAME"/snap/backups "$SET_SYNC_PATH"
		echo ""
		echo -e "[${GREEN}✓${RESET}]Done."
		
		# Ask if this path should be added as an environment variable in ~/.bashrc
		# The following grep will only match on these three lines:
		# # snap-up sync folder path
		# export SET_SYNC_PATH=/any/valid-path_name
		# SET_SYNC_PATH=/any/valid-path_name
		if ! (grep -Pv "^(#|$)" ~/.bashrc | grep -Pq "^(|export )SET_SYNC_PATH=(/[a-zA-Z0-9_-]+){1,}$"); then

			function AddPath() {

				echo ""
				echo "Add this sync path as an environment variable to your ~/.bashrc?"
				echo ""
				until [[ $SET_SYNC_VAR =~ ^(y|n)$ ]]; do
					read -rp "[y/n]: " -e -i y SET_SYNC_VAR
				done
				
				if [ "$SET_SYNC_VAR" == "n" ]; then

					exit 0

				elif [ "$SET_SYNC_VAR" == "y" ]; then

					{
					echo ''
					echo '# snap-up sync folder path'
					echo 'export SYNC_CHOICE=y'
					echo "export SET_SYNC_PATH=$SET_SYNC_PATH"
					} >> ~/.bashrc

					echo -e "[${GREEN}✓${RESET}]Done. (Start a new shell for changes to take effect)"
				fi
			}

			# Execute the function, comment out 'AddPath' if you don't want to use this
			AddPath

		elif (grep -Pv "^(#|$)" ~/.bashrc | grep -Pq "^(|export )SET_SYNC_PATH=(/[a-zA-Z0-9_-]+){1,}$"); then
			
			function DelPath() {

				sleep 1
				
				echo ""
				echo "Remove SET_SYNC_PATH from ~/.bashrc?"
				until [[ $DEL_SYNC_VAR =~ ^(y|n)$ ]]; do
					read -rp "[y/n]: " -e -i n DEL_SYNC_VAR
				done
				
				if [ "$DEL_SYNC_VAR" == "n" ]; then
					exit 0
				elif [ "$DEL_SYNC_VAR" == "y" ]; then

					# Backup in case sed fails
					cp -n ~/.bashrc ~/.bashrc.bkup

					# Remove variables otherwise exit
					sed -i 's/^# snap\-up sync folder path$//g' ~/.bashrc || exit 1
					sed -i 's/^.*SYNC_CHOICE=.*y.*$//g' ~/.bashrc || exit 1
					sed -i 's/^.*SET_SYNC_PATH=\/.*$//g' ~/.bashrc || exit 1

					# Cleanup any newlines
					while (tail -n 1 ~/.bashrc | grep -Pq "^$"); do
						truncate -s -1 /home/"$USERNAME"/.bashrc
					done

					rm ~/.bashrc.bkup

					unset SYNC_CHOICE
					unset SET_SYNC_PATH
					
					echo -e "[${GREEN}✓${RESET}]Done. (Start a new shell for changes to take effect)"
				fi
			}

			# Execute the function, comment out 'DelPath' if you don't want to use this
			DelPath
		fi
			
	else
		echo "Empty path, quitting."
		exit 1
	fi

	exit 0
}

function CleanUp() {
	echo ""
	echo "Empty your backup directory?"
	echo ""
	until [[ $CLEAN_CHOICE =~ ^(y|n)$ ]]; do
		read -rp "[y/n]: " CLEAN_CHOICE
	done
	
	if [ "$CLEAN_CHOICE" == "y" ]; then
		echo ""
		echo "Are you sure?"
		echo -e "${YELLOW}THIS WILL DELETE ALL BACKUPS IN ~/snap/backups/${RESET}"
		echo ""
		until [[ $CLEAN_CONFIRM =~ ^(y|n)$ ]]; do
			read -rp "[y/n]: " CLEAN_CONFIRM
		done
		
		if [ "$CLEAN_CONFIRM" == "y" ]; then
			for folder in /home/"$USERNAME"/snap/backups/*; do
				echo "[DELETING]: $folder"
				rm -rf "$folder"
			done
			echo -e "[${GREEN}✓${RESET}]Done."
		fi
	fi
	
	exit 0
}


function ListSnapUps() {
	echo -e "[${BLUE}>${RESET}]Listing backups in ~/snap/backups/..."
	find /home/"$USERNAME"/snap/backups/ -type f -ls | rev | cut -d ' ' -f 1 | cut -d '/' -f 1,2 | rev

	if (echo "$SET_SYNC_PATH" | grep -Pq "^(/[a-zA-Z0-9_-]+){1,}$"); then
		echo ""
		echo "[i]Sync path found!"
		echo -e "[${BLUE}>${RESET}]Listing files in $SET_SYNC_PATH/backups/..."
		find "$SET_SYNC_PATH"/backups/ -type f -ls | rev | cut -d ' ' -f 1 | cut -d '/' -f 1,2 | rev
	fi
	
	echo -e "[${GREEN}✓${RESET}]Done."
}

function ShowManual() { 
	echo 'NAME
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
    
'
}

# Functions

if [ "$1" == "" ]; then
	SnapUp
elif [ "$1" == "-c" ] || [ "$1" == "--clean" ]; then
	CleanUp
elif [ "$1" == "-l" ] || [ "$1" == "--list" ]; then
	ListSnapUps
elif [ "$1" == "-s" ] || [ "$1" == "--sync" ]; then
	SyncUp
elif [ "$1" == "-t" ] || [ "$1" == "--test" ]; then
	TestRun
else
	ShowManual
fi
