# Virtual Machines

Quick reference for virtualization software usage.


### Performance

This [video by IppSec](https://youtu.be/2y68gluYTcc) details the benefits of having an ansible playbook over snapshots for long term VM backups. However, a secondary note was made on using a single file for the virtual disk vs splitting the disk into multiple files.

- Splitting the disk saves space
- It writes to the drive more frequently
- Has lower performance
- Can result in virtual disk errors with snapshots (I have encountered this on Linux hosts, but not Windows hosts)


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
