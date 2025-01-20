#!/bin/bash

# gsettings

# Starting with Ubuntu 24.04 some settings moved to gtk4.
# If you have issues in the future, `$ sudo apt install -y dconf-editor` on a test system to explore possible
# paths with the same key. This is how the new path for `show-hidden` (meaning hidden files) was found.
# The dconf-editor is also a good way to check your work, if there's an error a key will show up as "undefined by schema"

MAJOR_UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2 | cut -d '.' -f 1)

if [ "${EUID}" -eq 0 ]; then
	echo "You must run this as a non-root user. Quitting."
	exit 1
fi

# Screen locking
gsettings set org.gnome.desktop.screensaver lock-enabled 'true'

# Blank screen delay, how long until screen turns blank on idle
# 0 = immediately
gsettings set org.gnome.desktop.screensaver lock-delay 'uint32 0'

# Idle delay before system is considered "idle"
# 300 = 5 minutes
gsettings set org.gnome.desktop.session idle-delay 'uint32 300'
# 0 = never
#gsettings set org.gnome.desktop.session idle-delay 'uint32 0'

# Prevent notifications from appearing in the lock screen
gsettings set org.gnome.desktop.notifications show-in-lock-screen 'false'

# Configure trash, temp file retention period (set to 7 days)
gsettings set org.gnome.desktop.privacy remove-old-trash-files 'true'
gsettings set org.gnome.desktop.privacy remove-old-temp-files 'true'
gsettings set org.gnome.desktop.privacy old-files-age 'uint32 7'

# System Theme
gsettings set org.gnome.desktop.interface gtk-theme Yaru-dark
#gsettings set org.gnome.desktop.interface gtk-theme default

# Apps in the dock
gsettings set org.gnome.shell favorite-apps "['firefox_firefox.desktop', 'google-chrome.desktop', 'org.gnome.Nautilus.desktop', 'code.desktop', 'org.gnome.Terminal.desktop']"

# Gedit Preferences
#gsettings set org.gnome.gedit.preferences.editor scheme 'solarized-light'
gsettings set org.gnome.gedit.preferences.editor scheme 'oblivion'
#gsettings set org.gnome.gedit.preferences.editor scheme 'kate'
#gsettings set org.gnome.gedit.preferences.editor scheme 'yaru-dark'
#gsettings set org.gnome.gedit.preferences.editor wrap-mode 'none'

# Disable autorun of software and media
gsettings set org.gnome.desktop.media-handling autorun-never 'true'

# Disable automounting of media and drives
gsettings set org.gnome.desktop.media-handling automount false
gsettings set org.gnome.desktop.media-handling automount-open false

# Show hidden files and folders
gsettings set org.gtk.Settings.FileChooser show-hidden 'true'
gsettings set org.gtk.gtk4.Settings.FileChooser show-hidden 'true'

# Disable location settings
gsettings set org.gnome.system.location enabled 'false'

# Auto-hide the dock
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed 'false'

# Prevent usb devices from being mounted and read while screen is locked
if [[ $MAJOR_UBUNTU_VERSION -gt 18 ]]; then
	# Prevent usb devices from being mounted and read while screen is locked
	gsettings set org.gnome.desktop.privacy usb-protection-level 'lockscreen'
	gsettings set org.gnome.desktop.privacy usb-protection 'true'
fi

# Don't automatically send techincal reports, but prompt user for OK
# Crash reports still generate under /var/crash/ to review if apport enabled
gsettings set org.gnome.desktop.privacy report-technical-problems 'false'
gsettings set org.gnome.desktop.privacy send-software-usage-stats 'false'

# See /usr/share/glib-2.0/schemas/org.gnome.Terminal.gschema.xml
# See dconf list /org/gnome/terminal
# See dconf read /org/gnome/terminal/[..]/next-tab
# Some settings require a literal path
# Sets the hotkey combination of LCtrl+PgUp/PgDn to change terminal tabs (default in many cases, but ensures Left Ctrl works)
gsettings set org.gnome.Terminal.Legacy.Keybindings:/org/gnome/terminal/legacy/keybindings/ prev-tab '<Primary>KP_Page_Up'
gsettings set org.gnome.Terminal.Legacy.Keybindings:/org/gnome/terminal/legacy/keybindings/ next-tab '<Primary>KP_Next'

# You need to double quote the settings within brackets "[]" when setting keybinding keys via CLI like in this script
# Set switching workspaces to Ctrl + Super + < ^ v >
#gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Primary><Super>Right']"
#gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Primary><Super>Left']"
#gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-down "['<Primary><Super>Down']"
#gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-up "['<Primary><Super>Up']"

# Set moving applications to Ctrl + Super + Shift + < ^ v >
#gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-down "['<Primary><Super><Shift>Down']"
#gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "['<Primary><Super><Shift>Left']"
#gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "['<Primary><Super><Shift>Right']"
#gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-up "['<Primary><Super><Shift>Up']"
