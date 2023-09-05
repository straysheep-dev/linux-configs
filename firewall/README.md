# Firewall

Client and server configuration examples for:

- ufw
- iptables
- wireguard

*In most cases, you'll want the -client-base.sh script for a baseline policy of deny in, deny routed, allow out.*


## References

- <https://ubuntu.com/server/docs/security-firewall>


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
