# GnuPG

### The Configuration Files

`gpg.conf` specifies strong default settings for gpg. See the original source below for more options.

`gpg-agent.conf` and `gpg-bachrc` are the configurations for using gpg and ssh with a smartcard such as a YubiKey. PIN entry is handled by pinentry-curses via the terminal.

### yubi-mode.sh

```
Usage:
yubi-mode [gpg|otp]
```

Script to change between the pcscd daemon included with the [yubioath-desktop snap](https://snapcraft.io/yubioath-desktop), and the pcscd daemon from apt.

Useful if you use both otp codes and gpg functions via a yubikey, yubikeys cannot access both daemons simultaneously.

Install this script to your preferred location, with the correct permissions (root:root, 755) and add it to your PATH.

### Commands

Two commands to memorize:
```bash
# use when the agent cannot detect your key
gpg-connect-agent updatestartuptty /bye

# when using one identity on multiple keys, ie; using a backup key, gpg associates id's with key serial numbers
# use this command after removing key 1 and inserting key 2
gpg-connect-agent "scd serialno" "learn --force" /bye
```
Other commands to know:
```bash
# when switching between different keys that have different identities
pkill gpg-agent ; pkill ssh-agent ; pkill pinentry ; eval $(gpg-agent --daemon --enable-ssh-support); gpg-connect-agent updatestartuptty /bye

# If usbguard is installed, see if it's blocking the YubiKey:
dmesg | tail [-n 100] | grep -B 4 'Device is not authorized for usage'
# remove the device, then:
sudo usbguard watch
# insert the device, note the line '[device] <action>: id=<id>', Ctrl+c the usbguard listener
sudo usbguard add-device <device-id>

# Alternatively, with the YubiKey still connected, you can add the rule in the same way the yubi-mode script does:
ALLOW_RULE="$(sudo usbguard list-devices | grep -P "^\d+: block id \d{4}:\d{4} serial \"\" name \"YubiKey .+$" | sed 's/^[[:digit:]]\{1,3\}: block/allow/')"
echo "$ALLOW_RULE" | sudo tee -a /etc/usbguard/rules.conf > /dev/null
sudo systemctl restart usbguard
```

In all of the above cases, you can confirm your key is being detected properly if this command is successful:
```bash
gpg --card-status
```

### Sources:

<https://github.com/drduh/YubiKey-Guide/>

<https://github.com/drduh/config/blob/master/gpg.conf>

<https://github.com/drduh/config/blob/master/gpg-agent.conf>
