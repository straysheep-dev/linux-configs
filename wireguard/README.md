# wireguard

This README attempts to provide examples as a quick reference for manually configuring wireguard endpoints.

This page on the offical wireguard site <https://www.wireguard.com/quickstart/> covers all of the basics when configuring an interface.

While this page <https://www.wireguard.com/netns/> goes into more detail on networking capabilities.

### Parameters

- `AllowedIPs` in the context of the client means 'destination IPs to be routed over wireguard'
	* EXAMPLE: `0.0.0.0/0,::/0` routes **all** traffic over wireguard
	* EXAMPLE: `172.16.0.0/24,fc70:9a12:9:2bbf::/64` routes traffic destined only to those private address ranges over wireguard (bridging two LANs across the public internet)

- `AllowedIps` in the context of the server means 'client IPs allowed to connect to this vpn'
	* EXAMPLE: `10.22.22.2/32,fd42:42:42::2/128` a client's wireguard interface must be one of these listed IP's in addition to having the correct private / public / preshared keys.

### Firewall Requirements

Here `wg` is used generically to reference wireguard interfaces. `eth` is used to reference the 'public' or externally facing network interface of the device.

- DNS servers must be configured to 'allow' traffic from the wireguard interface subnet in their access-control lists

- Inbound UDP to the listening wireguard service port must be allowed, forwarding from eth -> wg is not necessary

- Outbound NAT as well as forwarding from wg -> eth is necessary to route traffic out of the wireguard server to the next network

- Forwarding within the Linux kernel must be enabled
	* EXAMPLE: manually enable forwarding:
		- `sudo su` then `echo '1' > /proc/sys/net/ipv4/ip_forward`
		- `sudo su` then `echo '1' > /proc/sys/net/ipv6/conf/all/forwarding`
	* EXAMPLE: using `sysctl` to enable forwarding:
		- sudo sysctl -q -n -w net.ipv4.ip_forward="1"
		- sudo sysctl -q -n -w net.ipv6.conf.all.forwarding="1"
	* EXAMPLE: using `ufw` to enable forwarding
		- sudo ufw allow routed

- NAT masquerading must be enabled with `iptables` or similar (`ufw` alone cannot do this)
	* EXAMPLE: using `iptables` to enable NAT masquerading
		- `iptables -t nat -A POSTROUTING -o wg -j MASQUERADE`
		- `ip6tables -t nat -A POSTROUTING -o wg -j MASQUERADE`

The following script is the minumum firewall requirements for a debian-based server running wireguard with `ufw` managing the firewall.

The following is assumed:

- `eth0` is the public networking interface
- `wg0` is the wireguard interface and configuration filename
- `ufw` is installed
- `43891` is the externally facing port wireguard is listening on
- `10.22.22.0/24` is the wireguard IPv4 subnet
- `fc77:7:7::/64` is the wireguard IPv6 subnet
- A dns daemon on the wireguard server is listening locally on `10.22.22.1` and `fc77:7:7::1` (both wireguard interfaces)
- `/etc/wireguard/wg0.conf` has no PostUp|Down scripts

```bash
sudo wg-quick down wg0
sudo iptables -F     # Flush all chains
sudo iptables -X     # Delete all user-defined chains
sudo ip6tables -F    # Flush all chains
sudo ip6tables -X    # Delete all user-defined chains
sudo ufw reset
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow routed
sudo ufw allow in on eth0 to any proto udp port 43891 comment 'wg'
sudo ufw allow in on wg0 from 10.22.22.0/24 to 10.22.22.1 comment 'wg -> dns'
sudo ufw allow in on wg0 from fc77:7:7::/64 to fc77:7:7::1 comment 'wg -> dns'
sudo ufw route allow in on wg0 from 10.22.22.0/24 out on eth0 to any comment 'wg -> eth'
sudo ufw route allow in on wg0 from fc77:7:7::/64 out on eth0 to any comment 'wg -> eth'
sudo sysctl -q -n -w net.ipv4.ip_forward="1"
sudo sysctl -q -n -w net.ipv6.conf.all.forwarding="1"
sudo wg-quick up wg0
```

Confirm you can ping, and resolve DNS over, the wireguard tunnel:

```bash
ping 10.22.22.1
ping -6 fc77:7:7::1
nslookup google.com 10.22.22.1
dig @fc77:7:7::1 google.com
```

Additionally you could confirm web traffic can traverse the tunnel with a python web server.

For a less common example, we'll run Windows as the Wireguard server and host an index.html file on the wireguard address, using python.

```powershell
# on Windows, after configuring wireguard
cd 'C:\Program Files\WireGuard'
.\wireguard.exe /installtunnelservice 'C:\Program Files\WireGuard\Data\Configurations\wg0.conf.dpapi'
cd 'C:\Users\$USER\AppData'
mkdir www
cd www
Write-Output -InputObject "<h1>Hello, world!</h1>" | Out-File -FilePath .\index.html -Encoding ASCII
New-NetFirewallRule -Name WebServer -Enabled True -Direction Inbound -LocalAddress 10.22.22.1 -LocalPort 80 -RemoteAddress 10.22.22.0/24 -Protocol TCP -DisplayName WebServer
py.exe -m http.server 80 --bind 10.22.22.1
```

```bash
# on Wireguard client
sudo wg-quick up wg0
curl -Lf 'http://10.22.22.1:80/index.html'
```

Keep in mind in this configuration, there is no client isolation, or egress filtering. It is only enough for traffic to successfully traverse the tunnel.

---

## Sample Configurations

Keys can be (quickly) generated using the methods described in <https://www.wireguard.com/quickstart/>

### /etc/wireguard/wg0.conf client example (generic vpn)

This client is configured to route all traffic to the wireguard endpoint, and use the DNS server on that endpoint.

**TIP**: Running `sudo wg-quick up wg0` with wg0.conf in /etc/wireguard will automatically read that file, otherwise specify the full path to the conf file.

In the following examples `<wg-ipv4-addr>` means the IP address of the wireguard interface on the server, not the server's public IP.

`<peer-ipv4-addr>` refers to the IP address assigned to the client's wireguard interface.

```
[Interface]
PrivateKey = <private-key>
Address = <wg-ipv4-addr>/32,<wg-ipv6-addr>/128
DNS = <dns-server-1>,<dns-server-2>

[Peer]
PublicKey = <public-key>
PreSharedKey = <preshared-key>
Endpoint = <server-ipv4-addr:port>
AllowedIPs = 0.0.0.0/0,::/0
```

```
[Interface]
PrivateKey = <private-key>
Address = 10.22.22.2/32,fd42:42:42::2/128
DNS = 10.22.22.1,fd42:42:42::1

[Peer]
PublicKey = <public-key>
PresharedKey = <preshared-key>
Endpoint = 192.168.2.100:43891
AllowedIPs = 0.0.0.0/0, ::/0
```

### wg0.conf server example (generic vpn)

This server is configured to accept the listed clients, which can have `#` comments within the file.

```
[Interface]
Address = <wg-ipv4-addr>/24, <wg-ipv6-addr>/64
ListenPort = <port>
PrivateKey = <private-key>
PostUp = <commands>
PostDown = <commands>

# Comment
[Peer]
PublicKey = <public-key>
PresharedKey = <preshared-key>
AllowedIPs = <peer-ipv4-addr>/32,<peer-ipv6-addr>/128

# Comment
[Peer]
PublicKey = <public-key>
PresharedKey = <preshared-key>
AllowedIPs = <peer-ipv4-addr>/32,<peer-ipv6-addr>/128

# Comment
[Peer]
PublicKey = <public-key>
PresharedKey = <preshared-key>
AllowedIPs = <peer-ipv4-addr>/32,<peer-ipv6-addr>/128
```

```
[Interface]
Address = 10.22.22.1/24,fd42:42:42::1/64
ListenPort = 43891
PrivateKey = <private-key>
PostUp = /usr/local/bin/wg-PostUp.sh
PostDown = /usr/local/bin/wg-PostDown.sh

# Client 1 
[Peer]
PublicKey = <public-key>
PresharedKey = <preshared-key>
AllowedIPs = 10.22.22.2/32,fd42:42:42::2/128

---8<---
```

### Linux server /etc/wireguard/params example

This file is created when using <https://github.com/angristan/wireguard-install>.

It's used as a list of variables to be read only by root for scripting.

```
SERVER_PUB_IP=
SERVER_PUB_NIC=
SERVER_WG_NIC=
SERVER_WG_IPV4=
SERVER_WG_IPV6=
SERVER_PORT=
SERVER_PRIV_KEY=
SERVER_PUB_KEY=
CLIENT_DNS_1=
CLIENT_DNS_2=
```
