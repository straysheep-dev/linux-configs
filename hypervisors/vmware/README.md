# VMware Workstation for Linux

Configurations for VMware Workstation


| Resource                | Link
| ----------------------- | -------------------------------------------------------------------- |
| `Download VMware`       | <https://www.vmware.com/go/getworkstation-linux>                     |
| `Kali Documentation`    | <https://www.kali.org/docs/virtualization/install-vmware-host/>      |
| `Fedora Documentation`  | <https://docs.fedoraproject.org/en-US/quick-docs/how-to-use-vmware/> |
| `Debian Documentation`  | <https://wiki.debian.org/VMware>                                     |
| `Arch Documentation`    | <https://wiki.archlinux.org/title/VMware>                            |
| `Kernal Module Patches` | <https://github.com/mkubecek/vmware-host-modules>                    |

## Install

1. Download the `VMware-Workstation-Full-<version>.x86_64.bundle` installer file from <https://www.vmware.com/go/getworkstation-linux>

2. Install necessary packages (this can be done before, or after, running the bundle installer, but before launching `vmware` itself)

**Debian / Ubuntu**:
```bash
sudo apt install -y gcc make build-essential libaio1 linux-headers-$(uname -r)

# vlan is not always necessary on Ubuntu
sudo apt instally -y vlan
```

**Fedora**:
```bash
sudo dnf install kernel-devel kernel-headers gcc gcc-c++ make git
```

3. Run the .bundle installer with `bash` or `sh`, it may fail without specifying the shell.

```bash
sudo bash ./vmware-installer.bundle
```

## Patching the Kernel Modules

| Module  | Path to module source code               |
| ------- | ---------------------------------------- |
| `vmmon` | /usr/lib/vmware/modules/source/vmmon.tar |
| `vmnet` | /usr/lib/vmware/modules/source/vmnet.tar |

On systems where the modules fail to build and install correctly, use the patched modules for your version here:

<https://github.com/mkubecek/vmware-host-modules>

The patches have two methods of applying them (use one):

<https://github.com/mkubecek/vmware-host-modules/blob/master/INSTALL>

- Option 1: build new modules using the patch and replace the modules installed from the bundle installer
- Option 2: apply the patch directly to the modules from the VMware bundle installer and rebuild them

Additional references using these patches:

- <https://www.kali.org/docs/virtualization/install-vmware-host/#too-newer-kernel>
- <https://docs.fedoraproject.org/en-US/quick-docs/how-to-use-vmware/#_installation_2>
- <https://wiki.debian.org/VMware#Kernel_Patches>
- <https://wiki.archlinux.org/title/VMware#Kernel_modules>

On systems frequently relying on these patches, both the Kali and Fedora docs have examples scripting this process during kernel updates:

- <https://docs.fedoraproject.org/en-US/quick-docs/how-to-use-vmware/#_deal_with_kernel_updates>
- <https://www.kali.org/docs/virtualization/install-vmware-host/#vmware-host-modules--kernel-updates>

Start `vmware` and the new modules will be installed automatically.

If SecureBoot is enabled, the modules **will build correctly** but fail to install because they aren't signed.

You can confirm the modules were built with:

```bash
modinfo -n vmmon
modinfo -n vmnet
```

Which should show the filesystem path where they exist.

---

## Signing the Kernel Modules (First Time Setup)

<https://kb.vmware.com/s/article/2146460>

For systems with SecureBoot enabled, after any of the following...

- kernel update
- updating VMware Workstation
- patching kernel modules

... you will need to sign the new `vmmon` and `vmnet` modules (for the kernel to load them).

The sign-file script shows the arguments required:

```bash
user@pc:~$ /usr/src/linux-headers-$(uname -r)/scripts/sign-file --help

/usr/src/linux-headers-5.13.0-41-generic/scripts/sign-file: invalid option -- '-'
Usage: scripts/sign-file [-dp] <hash algo> <key> <x509> <module> [<dest>]
       scripts/sign-file -s <raw sig> <hash algo> <x509> <module> [<dest>]
```

### Create a Signing Key

**NOTE**: while not required, it's recommended to make a key that is not a CA, and is only usable for code signing.

See the 'STANDARD EXTENSIONS' section of `man x509v3_config`.

Essentially, have the following in your openssl config used to make the key in the next step:

- `basicConstraints=CA:FALSE`
- `keyUsage=digitalSignature`

The Fedora Project Documentation provides a [configuration file suitable for generating a kernel module signing key](https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_Kernel_Modules/#sect-generating-a-public-private-x509-key-pair) under the [Creative Commons BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

- Replace `CN = Organization signing key` with `CN = VMware Secure Boot Module Signing Key`
- Make any additional changes you may require
- Write this `.conf` file to /var/lib/shim-signed/mok/

```
[ req ]
default_bits = 4096
distinguished_name = req_distinguished_name
prompt = no
string_mask = utf8only
x509_extensions = myexts

[ req_distinguished_name ]
#O = Organization                           # optional
CN = VMware Secure Boot Module Signing Key
#emailAddress = E-mail address              # optional

[ myexts ]
basicConstraints=critical,CA:FALSE
keyUsage=digitalSignature
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
```

Use the above configuration file to generate the X.509 public private key pair. The `openssl` command has also been updated to reflect what's shown in the [Fedora User Docs](https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_Kernel_Modules/#sect-generating-a-public-private-x509-key-pair):

```bash
# Change to the directory containing your machine owner keys, which is only readable by root
cd /var/lib/shim-signed/mok/

# Create a key for code signing
sudo openssl req -x509 -new -nodes -utf8 -sha256 -days 36500 -batch -config signing_key.config -outform DER -out VMw.der -keyout VMw.priv

# Sign both vmmon and vmnet with the new key
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmmon)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmnet)
```

#### Importing the Key with mokutil

**NOTE**: In some cases, you may need to re-import signing keys at a later time. For example, after updating the UEFI/BIOS.

`mokutil` requires a password during the boot sequence to import keys into the UEFI system.

This password exists solely for this purpose, of ensuring you have physical access to the device during the mokutil dialogues.

Create an 8-16 character password for this purpose using your **password manager**.

Be sure to have access to it while the machine is powered off, you'll be prompted to enter it during the boot process.

Import the *public key*, in this case the `.der` file:

```bash
sudo mokutil --import VMw.der
# enter the password you just created
reboot
```

Follow the prompts in the UEFI/BIOS menu to enroll the new MOK key.

These prompts will automatically appear when a mokutil operation is pending.

# IMPORTANT

From here it's critical to remove the private key you just created and imported into MOK from the filesystem.

A local attacker with root privileges can bypass all of the protections of Secure Boot by using this (or any enrolled `.priv` / private key locally available) to sign a malicious kernel module.

The public part of the key pair (the `.der` file) can safely remain on the system. Should you ever need to import it into MOK again, for example after updating your system's firmware, you can do so using the `.der` file alone.

For managing the `.priv` or private key, there are roughly three approaches to this:

- For a lower threat model, there is a convenience to having the keys available on disk. Secure Boot being enabled alone is a good baseline.

- For a mid-level threat model, moving those keys to an external storage device or backing them up to a password manager to be retrieved when kernel modules need updated and signed is a reasonable compromise.

- For a higher threat model, deleting the private keys after signing is recommended. Using a script you can create new private keys to sign modules as needed. The overhead here is the additional reboot required when enrolling new keys through `mokutil`. This means each time a module needs signed, you must create a MOK password and walk through the prompts at boot to enroll the new key. Additionally you may want to delete previous keys from MOK with `sudo mokutil --delete-key <sha1-hash>` when creating new keys.


## Signing the Kernel Modules (Recurring Updates)

As mentioned above, anytime after the kernel, the vmmon / vmnet modules, or VMware itself is updated:

*NOTE: If you update VMware by letting the latest bundle installer uninstall the previous version, you can sign the new kernel modules immediately after, requiring only one reboot for the new modules to be loaded.*

- Start VMware.
- Let it build the modules successfully but fail to load them into the running kernel.
- Sign the newly compiled kernel modules with the following commands, and reboot.

```bash
# This assumes your secure boot keys are stored under /var/lib/shim-signed/mok
# and that you created key files named VMw.priv and VMw.der for the purpose of signing the VMWare kernel modules
cd /var/lib/shim-signed/mok/
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmmon)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmnet)
```

## Manually Configure Networking

`/etc/vmware/networking`

`/etc/vmware/netmap.conf`

On some installs of VMware Workstation (this has only happened on Ubuntu 20.04, I have not been able to reproduce this on Fedora >=34 or Kali >=2021.4), the networking configuration files are not written during install. This will cause networking to fail until a valid set of configuration files are written. This is easy to miss if for example you're updating VMware Workstation to a new version, as those files will be present unless you removed them.

Run `vmware-netcfg` or from the VMware Workstation menu `Edit > Virtual Network Editor`

If it segfaults, check if `/etc/vmware/networking` and `/etc/vmware/netmap.conf` exist.

If they don't exists, write the defaults manually using the templates below.

This configuration is the same as the default you get from a fresh install, only here you're deciding the values of the network adapters. You'll end up with the following:

* A Bridged network adapter
* A NAT network adapter
* A Host-only network adapter

#### /etc/vmware/networking:

```conf
VERSION=1,0
answer VNET_1_DHCP yes
answer VNET_1_DHCP_CFG_HASH <hash>
answer VNET_1_DISPLAY_NAME 
answer VNET_1_HOSTONLY_NETMASK <netmask>
answer VNET_1_HOSTONLY_SUBNET <network-ip-addr>
answer VNET_1_VIRTUAL_ADAPTER yes
answer VNET_8_DHCP yes
answer VNET_8_DHCP_CFG_HASH <hash>
answer VNET_8_DISPLAY_NAME 
answer VNET_8_HOSTONLY_NETMASK <netmask>
answer VNET_8_HOSTONLY_SUBNET <network-ip-addr>
answer VNET_8_NAT yes
answer VNET_8_NAT_PARAM_UDP_TIMEOUT 30
answer VNET_8_VIRTUAL_ADAPTER yes
```

#### /etc/vmware/netmap.conf:

```conf
# This file is automatically generated.
# Hand-editing this file is not recommended.
network0.name = "Bridged"
network0.device = "vmnet0"
network1.name = "HostOnly"
network1.device = "vmnet1"
network8.name = "NAT"
network8.device = "vmnet8"
```

* You can delete the `<hash>` altogether, and VMware will automatically generate the correct value upon starting Workstation.
* `<netmask>` is any valid netmask (ie; 255.255.0.0)
* `<network-ip-addr>` is whatever network address of the subnet you specify. (ie; 172.16.10.0)

Alternatively, you can also import a working network configuration from another existing VMware installation:

<https://docs.vmware.com/en/VMware-Workstation-Pro/16.0/com.vmware.ws.using.doc/GUID-AC956B17-30BA-45F7-9A39-DCCB96B0A713.html>


## Uninstall

#### Method 1

- Power off any virtual machines
- Close the VMware Workstation application

```bash
# review usage
vmware-installer --help

# list installed software
vmware-installer -l

# uninstall specified software package
sudo vmware-installer -u vmware-workstation
```

#### Method 2

- On occassion, you may need to manually uninstall and remove VMware (after a failed install).

- See the following article for exact steps: <https://kb.vmware.com/s/article/38>


## Update

#### Method 1

- From the VMware Workstation application menu; `Help > Software Updates > Check for Updates`

- Follow the prompts to update VMware.

##### Method 2

- Obtain the latest bundle installer from <https://www.vmware.com/go/getworkstation-linux>

- ***Optional:*** [Uninstall](#uninstall) the currently installed version of VMware Workstation. This will require two reboots to sign the new kernel modules.

- [Install](#install) from the latest bundle installer. This will automatically handle uninstalling the previous version.

- If SecureBoot is enabled, [sign the kernel modules](#signing-the-kernel-modules-recurring-updates) just like before:

```bash
cd /var/lib/shim-signed/mok/
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmmon)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmnet)
```

- Reboot the system.

Launch VMware Workstation, walk through the prompts, then check to ensure both kernel modules are loaded:
```bash
lsmod | grep -P "vm(mon|net)"
```

### Preferences

Changing the `Default Location for Virtual Machines` under `Edit` > `Workspace` to an external drive for example, may result in no VM tabs being available when opening the VMware Workstation application.

To repopulated the tabs bar with all of your virtual machines, go to `View` > `Customize` > `Library`.

You'll see by clicking on each virtual machine, it will automatically be added as a tab in the UI.

Hold either the `^` or `v` arrows to scroll through the list and quickly populate the tabs bar.

### Suspend vs Suspend Guest

[Suspend and Resume a Virtual Machine](https://docs.vmware.com/en/VMware-Workstation-Pro/16.0/com.vmware.ws.using.doc/GUID-A4536112-10A6-4574-ADE5-60D9BBAE1F02.html)

- `Suspend` / `Resume`: Hard options, suspends the virtual machine while **leaving it connected to the network**
- `Suspend Guest` / `Resume Guest`: Soft options, suspends the virtual machine, and disconnects it from the network

The `.vmss` and `.vmem` files created to suspend a VM are the VM's memory contents written to disk.

Reviewing these files with `binwalk <file>`, `foremost -v -i <file>`, `strings -n 10 <file> | less -S`, or similar, will reveal drastically different results if the virtual machine is encrypted or not.

`foremost` will likely produce the quickest and clearest results.

It's strongly recommended to encrypt VM's that will be suspended, as data injection or data theft from the host may become possible on unencrypted memory files. The same applies to data contained within the disk images, suspended or not.


## Troubleshooting

The linked resources [above the install](#vmware-workstation-for-linux) section will have detailed solutions for most anything you'll encounter.

The following are specific issues I've identified during usage.

---

### Kernel Modules Do Not Build

In the worst case scenario, after a kernel update you can enter the GRUB2 menu at boot, and boot using the previous kernel.

https://www.gnu.org/software/grub/manual/grub/grub.html#Simple-configuration

Set `GRUB_TIMEOUT_STYLE=countdown` and update grub:

```bash
sudo update-grub
```

When you see the countdown prior to boot, press `ESC` or `F4`. GRUB can also be accessed by holding `Shift` during boot.

From here choose a previous kernel version to boot into the OS.

---

### VM's Copied from Another Host Fail to Boot

Check the VM's configuration on the source host (the machine you copied the VM from), under `VM > Settings > Hardware > Processors` to see if `Virtualize IOMMU` is available and checked. If it's not available on the destination host (the host you copied the VM to), and this VM has it enabled, such as Windows guests with VBS (Virtualization Based Security), the VM will fail to boot.

In one case with a Windows 11 VM, it quickly failed to boot producing a stopcode that does not directly point to the issue being related to the hypervisor. Booting into safe mode works, however attempting to reinstall or recover Windows locally always fails.

To fix this, you'll need to turn both of the following options off on the host that has VBS and IOMMU support, **prior to copying the VM's to the destination machine that does not support them**:

- `VM > Settings > Options > Advanced` uncheck `Enable VBS (Virtualization Based Security) support`
- `VM > Settings > Hardware > Processors` uncheck `Virtualize IOMMU (IO memory management unit)`

### /etc/vmware/networking does not exist

Segfault if `/etc/vmware/networking` or `/etc/vmware/netmap.conf` do not exist.

See [manually configure networking](#manually-configure-networking) above.

---

### Copy and Paste, Drag and Drop Issues

In some cases these functions will stop working. 

**If VMware Tools or `open-vm-tools*` packages were updated at runtime:**

- Reboot the VM

**If the VMware Tools or `open-vm-tools*` packages were not updated:**

- `Suspend` all currently powered on guests
- Close the VMware Workstation application
- Restart VMware Workstation
- Resume all suspended guests

**All other cases:**

- Try one or the other (if using copy and paste, try drag and drop)
- Try `Ctrl+c`, `Ctrl+v` to copy and paste
- Try `Right-Click > Copy`, `Right-Click > Paste` to copy and paste
- Be sure to `Left-Click` inside the source and destination 'areas' before executing a copy or paste action
	* Left click inside the VM's folder window, then copy the file, next left click inside your host's folder window, and paste the file
- Try different source and destination locations
	* copy and paste to the destination's desktop rather than a folder window
	* drag and drop a file from the source file system to an application window on the destination, such as an audio file onto a media player application window

There are other creative ways around this:

- Create a shared folder as 'read-only' to obtain files from the host
- Use a USB device to transfer files to and from the host
- Use `ssh` to `scp` files to and from the host

If all else fails, the builtin `vmrun` commands will always work from the host as long as the guest VM has VMware Tools or `open-vm-tools*` installed:

- `vmrun -T ws CopyFileFromGuestToHost /path/to/your/vm/vm.vmx C:\\Source\\Path\\On\\The\\Guest\\file.txt /Destination/Path/On/The/Host/file.txt`
- `vmrun -T ws CopyFileFromHostToGuest /path/to/your/vm/vm.vmx /Source/Path/On/The/Host/file.txt C:\\Destination\\Path\\On\\The\\Guest\\file.txt`

The downside is it's much slower to type the command instead of `Ctrl+c`, `Ctrl+v`. You could create a shell (bash or powershell) script to handle these operations instead.

If your VM is encrypted, when writing a script you can assign the encryption password to a variable that's read as input during execution. This prevents providing the password numerous times (from your password manager) depending on the script, you'll only need to provide it once per operation.

---

### YubiKey VMware Passthrough

- Troubleshooting YubiKey device passthrough:
<https://support.yubico.com/hc/en-us/articles/360013647640-Troubleshooting-Device-Passthrough-with-VMware-Workstation-and-VMware-Fusion>

- Editing .vmx files:
<https://kb.vmware.com/s/article/2057902>

1. Disconnect the YubiKey
2. Power off the virtual machine
3. If `VM > Options > Access Control > Encryption` is set, remove encryption temporarily to be able to edit the .vmx configuration file for this machine.
4. **If any of them are missing**, add the following lines anywhere within the configuration file (not at the top, typically add these near any of the other usb configuration lines, or at the very bottom. It will not hurt to ensure all three are present **only once** per config file):

```vmx
usb.generic.allowHID = "TRUE"
usb.generic.allowLastHID = "TRUE"
usb.quirks.device0 = "0x1050:0x0407 allow"
```
4. Save, optionally close and re-open the VMware Workstation application
5. Take a snapshot to preserve your edits to the .vmx file if you use snapshots for this VM
6. Re-encrypt the VM (setting encryption / access control is independant of snapshots).
5. Power on the virtual machine
6. Reconnect the YubiKey
7. The YubiKey should be visible under `VM > Removeable Devices > Yubico.com YubiKey ...`, choose to Connect it (not the `Shared YubiKey ...` if that's listed)
8. Confirm the YubiKey is present within the VM:
```bash
lsusb | grep -i 'yubikey'
gpg --card-status
```

You may also notice some quirks if you do not go to `VM > Removeable Devices > Yubico.com YubiKey ...> Disconnect` before powering off the VM.

If this happens, you can disconnect / reconnect the key from the host. At this point, the host should have control of the key again, and you'll be able to pass it through to any guest configured to accept it.

Generally the fastest way back to a working baseline when troubleshooting key passthrough with drivers is disconnecting the key before reconnecting and choosing to connect it to a VM. In rare cases (specifically where the `yubioath-desktop` [snap package](https://snapcraft.io/yubioath-desktop) for [managing OTP codes stored on a YubiKey](https://github.com/Yubico/yubioath-desktop) and the host's `scdaemon` are attempting to both read the key and you also try to connect it to a VM) you may need to reboot the system.

---

### VMware GUI Frozen or Unresponsive

If a VMware VM gets stuck (anything from unresponsive, to the entire GUI of VMware Workstation is locked up) `kill` the `vmware-vmx` process tied to starting that VM's `.vmx` file.

Your other running instances will be fine and continue to run by default in the background if the GUI process dies and needs restarted (unless you changed this behavior in the settings).

This can be done from the Process tab in the System Monitor, or via `pgrep` / `pkill`:
```bash
pgrep -f '<name-of-vmx-file>'
pkill -f '<name-of-vmx-file>'

# example
pkill -f 'Server-22.04.vmx'
```

I've found one system where navigating to other VM tabs before some VM's are fully powered on will cause the VMware application GUI to lock up. Waiting 2-3 seconds until VM's reach the first splash screen in their boot process is typically enough.

### VM frozen after PC enters sleep state

Tested on Ubuntu 20.04 LTS, GNOME desktop

After waking, some VM's (and their tabs within the VMware Workstation GUI) will become frozen and not render.

- Mitigation: suspend all VM's prior to putting the host to sleep.
- Resolving frozen VM's: suspend any frozen VM, then power it on again.
	* In this case, VMware Workstation may lock up for a minute or two
		- Ubuntu may also prompt you with "This application is not responding"
		- Wait at least a minute or two for the process to complete
	* If graphical errors persist after resuming VM's suspended like this
		- Shutdown the VM, power it back on
---

### Taking screenshots from host

- Tested on Ubuntu 20.04 LTS, GNOME desktop

The way VMware Workstation handles window input can conflict with the Screenshot GNOME application when run from the desktop GUI.

Sometimes the GUI will lockup from this, especially when taking screenshots of specific areas instead of entire application windows or the full desktop.

One solution around this is using the `Super` key to bring all current desktop windows of the active workspace into view, and navigating the windows with the keyboard (directional arrows) and opening other applications with the `Type to search` box by simply typing on this screen. The mouse will not behave as expected in this state.

You can try restarting the GNOME desktop, or simply closing / suspending all VM's and rebooting.

An easy way around this error is by using the keyboard shortcuts listed under `Settings > Keyboard Shortcuts` for taking and saving screenshots.

---

