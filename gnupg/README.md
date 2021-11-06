# GnuPG

### The Configuration Files:

`gpg.conf` specifies strong default settings for gpg. See the original source below for more options.

`gpg-agent.conf` and `gpg-bachrc` are the configurations for using gpg and ssh with a smartcard such as a YubiKey. PIN entry is handled by pinentry-curses via the terminal.

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
```
In all of the above cases, you can confirm your key is being detected properly if this command is successful:
```bash
gpg --card-status
```

### Sources:

<https://github.com/drduh/YubiKey-Guide/>

<https://github.com/drduh/config/blob/master/gpg.conf>

<https://github.com/drduh/config/blob/master/gpg-agent.conf>