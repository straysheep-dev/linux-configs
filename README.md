# linux-configs
Various configuration files for unix/linux operating systems

### Licenses
Unless a different license is included with a file as `<filename>.copyright-notice` all files are released under the GPL-3.0

## To do:
- [x] create table of contents
- [ ] add apparmor profiles
- [ ] write overview/summary of the firefox policies
- [ ] add other configurations for ufw
- [ ] add other configurations for iptables
- [ ] add bind9 dns setup and implementation

## Contents
- [Firefox Configuration](firefox/)
    * [Policy Overview](firefox#policy-overview)
    * [Thanks and References](firefox#thanks-and-references)
    * [Differences from SSG Firefox Guide STIG](firefox#differences-from-ssg-firefox-guide-stig)
- [Chromium Configuration](chromium/)
    * [Policy Overview](chromium#policy-overview)
    * [Thanks and References](chromium#thanks-and-references)
    * [Differences from SSG Chromium Guide STIG](chromium#differences-from-ssg-chromium-guide-stig)
- [GnuPG](#gnupg)
    * [The Configuration Files](#the-configuration-files)
    * [Sources](#sources)
- [Firewall Scripts](#firewall-scripts)
    * [Why?](#why)
    * [Example Usage](#example-usage)
- [unbound](#unbound)
    * [Overview](#overview)
    * [Why?](#why)
    * [Blocking Domains In unbound.conf](#blocking-domains-in-unboundconf)
    * [Hosts Files](#hosts-files)
    * [Dns Blocklist Resources](#dns-blocklist-resources)
    * [Parsing Hosts Files to a File Formatted for unbound](#parsing-hosts-files-to-a-file-formatted-for-unbound)
    * [Dns Response Codes](#dns-response-codes)
    * [References](#references)

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
sudo mkdir /opt/setup-firwewall
sudo mv 'script' -t /opt/setup-firewall/
sudo ln -s /opt/setup-firewall/'<script>' /usr/local/bin/setup-firewall
# run the script as a command
sudo setup-firewall
```

# unbound

### Overview

This file takes the [base configurations](https://github.com/pfsense/pfsense/blob/master/src/etc/inc/unbound.inc) from a fresh pfSense install, adjusts it to work with ubuntu server (unbound+apparmor instead of chroot), enforces DNS over TLS resolution, and logs all replies to syslog.

### Why?

* Dns over Tls makes packet manipulation over the wire more difficult, making untrusted networks safer to use
* Blocking known malicious or unwanted domains as part of a defense in depth strategy
* To summarize a setup process with examples, adapt these to your own environment

## Blocking Domains In unbound.conf

**Method 1 (old):**
```
local-zone: "domain.toblock" redirect
local-data: "domain.toblock A 0.0.0.0"
local-data" "domain.toblock AAAA ::"
```
**Method 2 (best, requires unbound [release-1.13.1rc1](https://github.com/NLnetLabs/unbound/commit/3322f631e5927c5d3adb66da05f867c64bdcb9c9) or later):**
```
local-zone: "domain.toblock" always_null	# recommended, aka 'null' response
```
* <https://tools.ietf.org/html/rfc3513#section-2.5.2>
* Following RFC 3513, Internet Protocol Version 6 (IPv6) Addressing Architecture, section 2.5.2, the address 0:0:0:0:0:0:0:0 (or :: for short) is the unspecified address. It must never be assigned to any node and indicates the absence of an address. Following RFC1122, section 3.2, the address 0.0.0.0 can be understood as the IPv4 equivalent of ::.
- The client does not even try to establish a connection for the requested website
- Speedup and less traffic
- Solves potential HTTPS timeouts as requests are never performed

**Method 3 (alternative to Method 2):**
```
local-zone: "domain.toblock" always_nxdomain	# use if null response cannot be used
```
- Similar to NULL blocking, 
- Experiments suggest that clients may try to resolve non-existent domains more often compared to NULL blocking.

**NOTE:**
Use this line anywhere in the file to include the parameters of 'otherfile.conf' into your configuration:
```
include: "otherfile.conf"
```

## Hosts Files

<https://github.com/StevenBlack/hosts>

### block example.com via a hosts file

`0.0.0.0 example.com`

* This format is for a hosts file.
* Since hosts files are so ubiquitous they're a good place to start.
* Our goal is to convert the hosts file format to a format for Unbound.

To modify your current hosts file, look for it in the following places and modify it with a text editor.

* macOS (until 10.14.x macOS Mojave), iOS, Android, Linux: /etc/hosts file.
* macOS Catalina: /private/etc/hosts file.
* Windows: %SystemRoot%\system32\drivers\etc\hosts file.

## Dns Blocklist Resources:
```bash
# meta list of many malware, tracker, and ad servers - you would normally use this list alone
curl -Lf 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts' > 'meta-hosts.txt'

# domains actively serving a payload or added to urlhaus within -48 hours, used with other lists
curl 'https://urlhaus.abuse.ch/downloads/hostfile/' > 'urlhaus.txt'

# ad domains, used with other lists
curl -Lf 'https://raw.githubusercontent.com/StevenBlack/hosts/master/data/yoyo.org/hosts' > 'yoyo.txt'
```

## Parsing Hosts Files to a File Formatted for unbound

* To avoid parsing errors by working only with the beginning / end of lines
* The goal is adding `local-zone: "` in front and `" always_nxdomain` to the end of each line
* The parsing of the domain names themselves is minimal, as you're only affecting the `^` and `$`
* This is done because it's assumed that some domain names may be intentionally made to induce parsing errors of these types of lists

Example parsing a hosts file pointing to 0.0.0.0:
```bash
cat hosts.txt | sed '/^$/d' | sed 's/\r//g' | sed '/^#/!s/$[[:space:]]//g' | sed '/^#/!s/^0.0.0.0[[:space:]]/local-zone: "/g' | sed '/^#/!s/$/" always_nxdomain/g' > blocklist.conf
```

```sed '/^$/d'``` deletes all empty lines

```sed 's/\r//g'``` delete all carriage returns (CRLF, see ```info sed``` search '5.8 Escape Sequences')

```sed '/^#/!s/$[[:space:]]//g'``` remove any space or tab at the end of each line not beginning with a '#' (see ```info sed``` search '4.1 Addresses overview')

```sed '/^#/!s/^0.0.0.0[[:space:]]/local-zone: "/g'``` ignore all lines beginning with '#', match all lines starting with '0.0.0.0' + a space or tab, replace '0.0.0.0 ' with 'local-zone: "'

```sed '/^#/!s/$/" always_nxdomain/g'``` ignore all lines beginning with '#', append to the end of every line '" always_nxdomain'

Using all of the above, here's an example with mix of tabs and spaces, with '0.0.0.0' and '127.0.0.1' ahead of `domain`:
```bash
cat hosts.txt | sed '/^$/d' | sed 's/\r//g' | sed '/^#/!s/^0.0.0.0[[:space:]]//g' | sed '/^#/!s/^127.0.0.1[[:space:]]//g' | sed '/^#/!s/$[[:space:]]//g' | sed '/^#/!s/^/local-zone: "/g' | sed '/^#/!s/$/" always_nxdomain/g' > blocklist.conf
```

You can also wildcard your input files as ```cat *.txt```

Putting it all together:
```bash
cd $(mktemp -d)
curl 'https://urlhaus.abuse.ch/downloads/hostfile/' > 'urlhaus.txt'
curl -Lf 'https://raw.githubusercontent.com/StevenBlack/hosts/master/data/yoyo.org/hosts' > 'yoyo.txt'
cat *.txt | sed '/^$/d' | sed 's/\r//g' | sed '/^#/!s/^0.0.0.0[[:space:]]//g' | sed '/^#/!s/^127.0.0.1[[:space:]]//g' | sed '/^#/!s/$[[:space:]]//g' | sed '/^#/!s/^/local-zone: "/g' | sed '/^#/!s/$/" always_nxdomain/g' > blocklist.conf
sudo cp blocklist.conf /etc/unbound/unbound.conf.d/
sudo unbound-checkconf | grep 'no errors'
sudo systemctl restart unbound

# confirm NXDOMAIN response via dig:
dig @127.0.0.1 <domain-from-blocklist>
```


### DNS response codes:

https://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml


## From [unbound.conf](https://github.com/NLnetLabs/unbound/blob/master/doc/example.conf.in):
```
	# a number of locally served zones can be configured.
	# 	local-zone: <zone> <type>
	# 	local-data: "<resource record string>"
	# o deny serves local data (if any), else, drops queries.
	# o refuse serves local data (if any), else, replies with error.
	# o static serves local data, else, nxdomain or nodata answer.
	# o transparent gives local data, but resolves normally for other names
	# o redirect serves the zone data for any subdomain in the zone.
	# o nodefault can be used to normally resolve AS112 zones.
	# o typetransparent resolves normally for other types and other names
	# o inform acts like transparent, but logs client IP address
	# o inform_deny drops queries and logs client IP address
	# o inform_redirect redirects queries and logs client IP address
	# o always_transparent, always_refuse, always_nxdomain, always_nodata,
	#   always_deny resolve in that way but ignore local data for
	#   that name
	# o always_null returns 0.0.0.0 or ::0 for any name in the zone.
	# o noview breaks out of that view towards global local-zones.
	#
	# defaults are localhost address, reverse for 127.0.0.1 and ::1
	# and nxdomain for AS112 zones. If you configure one of these zones
	# the default content is omitted, or you can omit it with 'nodefault'.
	#
	# If you configure local-data without specifying local-zone, by
	# default a transparent local-zone is created for the data.
	#
	# You can add locally served data with
	# local-zone: "local." static
	# local-data: "mycomputer.local. IN A 192.0.2.51"
	# local-data: 'mytext.local TXT "content of text record"'
	#
	# You can override certain queries with
	# local-data: "adserver.example.com A 127.0.0.1"
	#
	# You can redirect a domain to a fixed address with
	# (this makes example.com, www.example.com, etc, all go to 192.0.2.3)
	# local-zone: "example.com" redirect
	# local-data: "example.com A 192.0.2.3"
	#
	# Shorthand to make PTR records, "IPv4 name" or "IPv6 name".
	# You can also add PTR records using local-data directly, but then
	# you need to do the reverse notation yourself.
	# local-data-ptr: "192.0.2.3 www.example.com"
```

### References:

<https://docs.pi-hole.net/ftldns/blockingmode/>

<https://github.com/pi-hole/pi-hole>

<https://github.com/NLnetLabs/unbound/blob/master/doc/example.conf.in>

<https://github.com/pfsense/pfsense/blob/master/src/etc/inc/unbound.inc>

<https://github.com/pfsense/docs/blob/master/source/dns/unbound-dns-resolver.rst>

<https://manpages.ubuntu.com/manpages/focal/man5/unbound.conf.5.html>

<https://github.com/StevenBlack/hosts>

<https://urlhaus.abuse.ch/api/>

<https://developers.cloudflare.com/1.1.1.1/dns-over-tls>

<https://developers.cloudflare.com/1.1.1.1/support-nat64>

<https://support.quad9.net/hc/en-us/articles/360041193212-Quad9-IPs-and-other-settings>

<https://developers.google.com/speed/public-dns/docs/using>

<https://developers.google.com/speed/public-dns/docs/dns-over-tls>

<https://developers.google.com/speed/public-dns/docs/dns64>
