# Virtual Machines

Quick reference for virtualization software usage.

## Maintaining VM Backups

Tested on:

- VMware
	* <https://www.vmware.com/products/workstation-pro.html>
- VirtualBox
	* <https://www.virtualbox.org/>

Before updating, compressing, cloning, or snapshotting a VM you use as a template to clone from:

Copy (`Copy-Item`, `rsync`, etc) the Virtual Machine's folder and all files to a backup directory or drive.

Using `rsync`:
```bash
rsync -arv --delete ~/vmware/Win10-x64 /media/$USERNAME/recovery/virtual-machines/
```
Using PowerShell:
```powershell
Copy-Item -Recurse -Path E:\Virtual-Machines\Ubuntu-20.04 -Destination B:\Recovery\Virtual-Machines\ -Force
```

- Do this before every major update to your template VM.
- Do this after daily updates for easy recovery.

To recover, copy the backup folder to a working directory, add the copy to your hypervisor's menu.

## Compress Virtual Machine Disk Size (vdi, vmdk, etc)

Not every method to compress disk space (quickly) consumed by virtual machines works the same.

These are some methods I've found to work best for each situation.

#### Linux VM:

From a terminal inside the VM:

1. `sudo journalctl --rotate --vacuum-size=<size>`
2. `dd if=/dev/zero of=zerofill bs=1M status=progress`
3. `rm zerofill`
4. `poweroff`
5. On the host, do one of the following:
	- VirtualBox `.vdi` specific:
		* `VBoxManage modifyhd --compact /path/to/file.vdi`
	- VMware, VirtualBox:
		* Clone VM > Full Clone

#### Windows VM:

1. Built in VMware functions:
	* VM > Manage > CLean Up Disks
	* VM > Settings > [Hard Disk] > Compact
	* VM > Settings > [Hard Disk] > Defragment
2. When built in functions no longer help, these steps reduce the VM to it's minimum required space (after completing the above built-in functions)
	- From within the Windows Guest: 
		* Win > Settings > System > Storage > Temporary files > Remove
	- On the Host:
		* VM > Manage > Clone > an existing clone or snapshot > create full clone


# Live OS

You can install the open-vm-tools during a live session on Debian:

```bash
sudo apt update && sudo apt install -y open-vm-tools-desktop
sudo systemctl restart open-vm-tools-desktop.service
```

---

# VMware Workstation for Linux

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

```bash
# Change to the directory containing your machine owner keys, which is only readable by root
cd /var/lib/shim-signed/mok/

# Create a key for code signing
sudo openssl req -new -x509 -newkey rsa:2048 -keyout VMw.priv -outform DER -out VMw.der -nodes -days 36500 -subj "/CN=VMware Secure Boot Module Signing Key/"

# Sign both vmmon and vmnet with the new key
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmmon)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmnet)
```

#### Importing the Key with mokutil

`mokutil` requires a password during the boot sequence to import keys into the UEFI system.

This password exists solely for this purpose, of ensuring authorization during the mokutil dialogues.

Create an 8-16 character password for this purpose using your **password manager**.

Be sure to have access to it while the machine is powered off, you'll be prompted to enter it during the boot process.

```bash
sudo mokutil --import VMw.der
# enter the password you just created
reboot
```

Follow the prompts in the UEFI/BIOS menu to enroll the new MOK key.

These prompts will automatically appear when a mokutil operation is pending.


## Signing the Kernel Modules (Recurring Updates)

As mentioned above, anytime after the kernel, the vmmon / vmnet modules, or VMware itself is updated:

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

- [Uninstall](#uninstall) the currently installed version of VMware Workstation.

- [Install](#install) from the latest bundle installer.

- Launch the VMware Workstation application, accept the license and walk through the prompts.

With SecureBoot enabled, you may try to launch a VM here and receive an error that 'vmmon' cannot be found.

Re-sign the kernel modules just like before:

```bash
cd /var/lib/shim-signed/mok/
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmmon)
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./VMw.priv ./VMw.der $(modinfo -n vmnet)
```

- Reboot the system.

Launch VMware Workstation and check to ensure both kernel modules are loaded:
```bash
lsmod | grep -P "vm(mon|net)"
```

## Troubleshooting

The linked resources [above the install](#vmware-workstation-for-linux) section will have detailed solutions for most anything you'll encounter.

The following are specific issues I've identified during usage.

---

### /etc/vmware/networking does not exist

Segfault if `/etc/vmware/networking` or `/etc/vmware/netmap.conf` do not exist.

See [manually configure networking](#manually-configure-networking) above.

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

### Copy & paste no longer works

Tested on Ubuntu 20.04 LTS, GNOME desktop

The easiest and quickest way to fix this: 

- `Suspend` all currently powered on guests
- Close the VMware Workstation application
- Restart VMware Workstation
- Resume all suspended guests

---

### Taking screenshots from host

- Tested on Ubuntu 20.04 LTS, GNOME desktop

The way VMware Workstation handles window input can conflict with the Screenshot GNOME application when run from the desktop GUI.

Sometimes the GUI will lockup from this, especially when taking screenshots of specific areas instead of entire application windows or the full desktop.

One solution around this is using the `Super` key to bring all current desktop windows of the active workspace into view, and navigating the windows with the keyboard (directional arrows) and opening other applications with the `Type to search` box by simply typing on this screen. The mouse will not behave as expected in this state.

You can try restarting the GNOME desktop, or simply closing / suspending all VM's and rebooting.

An easy way around this error is by using the keyboard shortcuts listed under `Settings > Keyboard Shortcuts` for taking and saving screenshots.

---
