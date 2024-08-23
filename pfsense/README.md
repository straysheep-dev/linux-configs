# pfSense pcap-service

This script is a self contained service / cron task. It's made to run on pfSense using `/bin/sh` instead of `/bin/tcsh`.

Pcap files are generated that can be ingested by [RITA](https://github.com/activecm/rita) for anomaly detection.

# pfSense Configs

This collection of configuration files is useful for provisioning a pfSense machine in a lab environment.

**WARNING: Restoring the entire `config-*` file appears to break the install. For now it's best to restore each component one at a time, and monitor the system from the admin dashboard. This can be done by either using the individual `.xml` files, or limiting the restore function to a specific area (e.g. Firewall Rules) when using the full `config-*.xml`.**

These files were produced from a virtual machine created in Proxmox. This is useful to know if you're deploying to, for example, VirtualBox. You will want to change the virtual network interface names as needed.

Files are separated based on what they configure, so you can choose one or more to apply based on your requirements.

The primary `config-pfsense-ce.lab.internal.xml` file just contains all of the configuration files in a single file, along with the defaults a new install of pfSense includes.

*Changes are detailed below, otherwise the defaults are left in place.*

## Data Removal

The following is a list of sections or values you can safely remove when exporting configs that will be shared publicly.

**It is not exhaustive, your config may have secrets or credentials through use of OpenVPN or Wireguard, adding users, and more. Review everything before publishing.**

- SSL / TLS Cert References
    - entire `<cert/>` section can be removed
    - unbound: `<sslcertref>STRING</sslcertref>`
- Firewall Rules
    - filter: `<updated>`, `<created>`, `<time>STRING</time>`
    - Any references to users editing the firewall rules
- tracker sections: `<tracker>0100000102</tracker>`
    - These can be manually set
- SSH
    - `<ssh>` data may contain the public key
- Packages
    - OpenVPN, Tailscale, Wireguard data will have keys in their backup files

## Domain, Hostname

- `pfsense-ce` is the machine's hostname
- `lab.internal` is the domain assigned

## Interfaces

There are four total interfaces (meaning you will need to attach a "wan" and make 3 additional virtual / internal interfaces).

- `vtnet0` (wan) NAT or physical hypervisor network bridge for internet access
- `vtnet1` (lan) management, virutal / internal network adapter
- `vtnet2` (opt1) trusted, virutal / internal network adapter
- `vtnet3` (opt2) untrusted, virutal / internal network adapter

Depending on your hypervisor, the name of the virtual interface (e.g. `vtnet0`) will change. Manually modify these as needed.

**Proxmox**

In Proxmox, create 3 new Linux Bridge devices for your network with all default settings. You can name them `pf_lan`, `pf_opt1`, and `pf_opt2` for simplicity. The built in `vmbr0` acts as the wan interface, shared by all other Proxmox VM's connected to it.

**VMware / Virtualbox / Hyper-V**

In the case of these desktop hypervisors, you want to create their equivalent of a VM-to-VM virtual network interface. It's an interface that's purely virtual, that the host cannot talk to, but allows VM's to communicate with each other.

- **Hyper-V**: Virtual switch, "Private" network
- **VMWare**: LAN Segment
- **VirtualBox**: Internal network

## Addresses

These addresses were chosen for readability, to try and avoid mistaking which subnet a host is in.

- **LAN**: `192.168.1.1/24`
- **OPT1**: `172.20.20.1/24`
- **OPT2**: `10.99.99.1/24`

## Firewall

Firewall rules were written based on the purprose for each interface.

WAN accepts SSH to the firewall (self), however **you will need to start the openssh service first**.

LAN has all the default rules, it's assumed anything in this network is trusted and able to manage the firewall + talk to all other subnets.

OPT1 and OPT2 are for regular use:

- OPT1 is considered "trusted" while OPT2 is considered "untrusted"
    - It's arbitrary which you use, since they both have the same rules
    - Basically they're two networks that are isolated from all other subnets
    - This is useful for example if you want to use OPT2 as a pentesting lab environment
- Both can only talk to the firewall on 53/udp and ICMP echo req
- Management ports on the firewall are dropped
- RFC1918 network addresses are dropped (can't talk to other private subnets, only their own subnet)
- CGNAT ranges are blocked in case you're running Tailscale on your host, these VM's would otherwise be able to reach your tailnet
- Both can access the public internet

## Aliases

Three aliases were created for easy firewall rule management.

- **RFC1918**: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, used to isolate private subnets
- **CGNAT**: `100.64.0.0/10`, use to limit access to Tailnets
- **Management**: `22/tcp`, `80/tcp`, `443/tcp`, used to limit access to the pfSense management interfaces

## DNS

Both the `system-*` file and the `unbound-*` file have DNS settings.

By default, the `system-*` uses Cloudflare and Quad9 for upstream DNS resolvers.

Unbound is told to only make queries to itself (localhost), forward all those queries upstream over TLS, log all queries made, and ignore all other DNS configuration's from the WAN.

You'll see under customization options:

```xml
<custom_options>c2VydmVyOgogICAgbG9nLXF1ZXJpZXM6IHllcwogICAgI2xvZy1yZXBsaWVzOiB5ZXMKICAgICNsb2ctdGFnLXF1ZXJ5cmVwbHk6IHllcw==</custom_options>
```

The base64 string decodes to the unbound custom logging options:

```bash
$ echo 'c2VydmVyOgogICAgbG9nLXF1ZXJpZXM6IHllcwogICAgI2xvZy1yZXBsaWVzOiB5ZXMKICAgICNsb2ctdGFnLXF1ZXJ5cmVwbHk6IHllcw==' | base64 -d
server:
    log-queries: yes
    #log-replies: yes
    #log-tag-queryreply: yes
```

If you don't need or want queries logged, simply remove the base64 string.

## DHCP

The new `kea` backend is set to be used by default, replacing the previous (soon deprecated) backend.

```xml
<dhcpbackend>kea</dhcpbackend>
```

## Accounts

The default login is still `admin::pfsense` (you could verify this in the `<system/>` block by cracking the bcrypt hash or just by logging in). However SSH is not enabled by default, so you can safely login from the LAN subnet and change this before enabling any remote administration services.

```xml
<user>
    <name>admin</name>
    <descr><![CDATA[System Administrator]]></descr>
    <scope>system</scope>
    <groupname>admins</groupname>
    <uid>0</uid>
    <priv>user-shell-access</priv>
    <bcrypt-hash>$2y$10$czSvHQRZC5SV0.XlLlxbieMfqHICy2WsmUhqyAqgxE3mOzBhhR2b.</bcrypt-hash>
</user>
```

## Cert

The entire TLS cert section has been removed, along with any references to the SSL / TLS cert. You'll have your own cert generated during install.

After applying a full `config-*` file, check to ensure the following are still set:

- System > Certificates > Certificates: "GUI Default" created during install should still be there
- Services > DNS Resolver > SSL / TLS Certificate: "GUI Default (`<string>`)" should be set here
    - Note the DNS setting only matters if you're using unbound to resolve internal subnet queries over TLS
    - This does not affect pfSense forwarding those queries upstream over TLS

## Web UI

- Switched to dark mode
- Added useful widgets to the dashboard
