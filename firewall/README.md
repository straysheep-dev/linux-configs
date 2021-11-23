# Firewall Scripts

### Why?

* Provide firewall / network setup scripts for different baselines
* No hardcoded unique variables
* Scripts can be accessed publicly
* Scripts can be installed as commands

### Example Usage:
```bash
# download the chosen script
cd $(mktemp -d)
curl -LfO '<script>'
# adjust permissions for usage
sudo chown root '<script>'
sudo chgrp root '<script>'
sudo chmod 755 '<script>'
# add the script to your path as a command
sudo mkdir /opt/scripts
sudo mv 'script' -t /opt/scripts/
sudo ln -s /opt/scripts/'<script>' /usr/local/bin/setup-firewall
# run the script as a command
sudo setup-firewall
```

# iptables-persistent

**The following description has only been tested on Ubuntu 20.04**

1. `sudo apt install -y iptables-persistent`
2. configure or modify iptables / ip6tables rules
3. `sudo netfilter-persistent save`

## Packages

Two packages are required for persistent iptables:

`iptables-persistent`: this handles the services that make configurations persistent

`netfilter-persistent`: this applies and manages the rules

## Plugin Files 

The two plugin files are POSIX shell scripts:

`/usr/share/netfilter-persistent/plugins.d/15-ip4tables`

`/usr/share/netfilter-persistent/plugins.d/25-ip6tables`

These plugin files call the builtin `iptables-save|restore` commands.

## Configuration Files

`/etc/iptables/rules.v4`

`/etc/iptables/rules.v6`

`/etc/default/netfilter-persistent`

Note: the rule configurations, like those set by `ufw`, are only readable by root.

## Services

The services created when using these packages, that manage and apply iptables rules at boot and shutdown:

`iptables.service` 

`netfilter-persistent.service` 

are both enabled automatically after install.
