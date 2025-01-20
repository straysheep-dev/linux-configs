#!/bin/bash

# dconf.sh

# Configures system-wide settings using dconf. This is the root / system-wide equivalent of gsettings in GNOME.
# To test / check key settings, use `dconf read/write` not `gsettings`.

# The profile itself must be named 'user' -> /etc/dconf/profile/user
# user-db:<name> must also be named 'user'
# system-db:<name> can be any name

# Starting with Ubuntu 24.04 some settings moved to gtk4.
# If you have issues in the future, `$ sudo apt install -y dconf-editor` on a test system to explore possible
# paths with the same key. This is how the new path for `show-hidden` (meaning hidden files) was found.
# The dconf-editor is also a good way to check your work, if there's an error a key will show up as "undefined by schema"

MAJOR_UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2 | cut -d '.' -f 1)

# Locked key / value pairs are still changeable on 18.04 for some reason.
if [[ $MAJOR_UBUNTU_VERSION -lt 20 ]]; then
	echo "[i] Some settings aren't locking on 18.04. Use gsettings.sh"
	echo "Quitting..."
	exit 1
fi

if [ "${EUID}" -ne 0 ]; then
	echo "You need to run this script as root"
	exit 1
fi

# Create a dconf profile and paths
if ! [ -e /etc/dconf/profile/user ]; then
	echo "[*]Creating dconf user profile..."
	echo "user-db:user
system-db:site" > /etc/dconf/profile/user
fi

if ! [ -e /etc/dconf/db/site.d ]; then
	echo "[*]Creating dconf site database..."
	mkdir /etc/dconf/db/site.d
	mkdir /etc/dconf/db/site.d/locks
fi

DCONFS=/etc/dconf/db/site.d
LOCKS=/etc/dconf/db/site.d/locks

# ===========================
# System-wide Locked Settings
# ===========================

# Disable auto-mount / auto-run of software and devices
echo '# Disable autorun and automount of software and external media
[org/gnome/desktop/media-handling]
autorun-never=true
automount=false
automount-open=false' > "$DCONFS"/00_media-handling
echo '# Disable autorun and automount of software and external media
/org/gnome/desktop/media-handling/automount
/org/gnome/desktop/media-handling/automount-open
/org/gnome/desktop/media-handling/autorun-never' > "$LOCKS"/media-handling
echo -e "[*]Automount disabled"
echo -e "[*]Autorun disabled"

# Configure screen locking
echo '# Enable screen locking
[org/gnome/desktop/screensaver]
lock-enabled=true' > "$DCONFS"/00_screen-lock
echo '# Enable screen locking
/org/gnome/desktop/screensaver/lock-enabled' > "$LOCKS"/screen-lock
echo -e "[*]Screenlock enabled"

# Configure screen lock timeout
echo "# Idle timeout for screen lock
[org/gnome/desktop/session]
idle-delay='uint32 300'" > "$DCONFS"/00_screen-idle-lock
echo '# Idle timeout for screen lock
/org/gnome/desktop/session/idle-delay' > "$LOCKS"/screen-idle-lock
echo -e "[*]Screenlock on idle enabled"

# Prevent notifications from appearing on the lock screen
echo "# Prevent notifications from appearing in the lock screen
[org/gnome/desktop/notifications]
show-in-lock-screen='false'" > "$DCONFS"/00_notifications
echo '# Prevent notifications from appearing in the lock screen
/org/gnome/desktop/notifications/show-in-lock-screen' > "$LOCKS"/notifications
echo -e "[*]Notifications on lock screen disabled"

# Show hidden files and folders by default
echo '# Show hidden files and folders (Ubuntu 22.04 and earlier)
[org/gtk/settings/file-chooser]
show-hidden=true

# Show hidden files and folders (Ubuntu 24.04 or later)
[org/gtk/gtk4/settings/file-chooser]
show-hidden=true' > "$DCONFS"/00_show-hidden
echo '# Show hidden files and folders (Ubuntu 22.04 and earlier)
/org/gtk/settings/file-chooser/show-hidden

# Show hidden files and folders (Ubuntu 24.04 or later)
/org/gtk/gtk4/settings/file-chooser/show-hidden' > "$LOCKS"/show-hidden
echo -e "[*]Show hidden files enabled"

# Disable location settings
echo '# Disable location settings
[org/gnome/system/location]
enabled=false' > "$DCONFS"/00_location
echo '# Disable location settings
/org/gnome/system/location/enabled' > "$LOCKS"/location
echo -e "[*]Location settings disabled"

# Enable usb-protection while the device is locked
echo "# Prevent usb devices from being mounted and read while screen is locked
[org/gnome/desktop/privacy]
usb-protection-level='lockscreen'
usb-protection=true" > "$DCONFS"/00_usb-protection
echo '# Prevent usb devices from being mounted and read while screen is locked
/org/gnome/desktop/privacy/usb-protection
/org/gnome/desktop/privacy/usb-protection-level' > "$LOCKS"/usb-protection
echo -e "[*]USB mount protection added to lock screen"

# Apply all settings
echo "[*]Updating dconf databases..."

dconf update

echo "[i]Changes will not take effect system-wide until the next login."
