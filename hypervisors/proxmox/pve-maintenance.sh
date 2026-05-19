#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 straysheep-dev

# AI-assisted Authorship
# The following models and tools were used for drafts, examples, or research:
# [Claude](https://claude.com/product/overview)

# Used along with other scheduled update tasks to safely handle
# unattended Proxmox host kernel updates + reboots by shutting
# down guest VMs and maintaining automated snapshots of them.
# Tested on a stand-alone Proxmox node, TODO: expand this to
# handle upgrades on a multi-node cluster.
# This script also simply handles weekly snapshots + pruning.

KEEP_SNAPSHOTS=3
LABEL_SNAPSHOTS="auto"
SNAPSHOT_NAME="${LABEL_SNAPSHOTS}_$(date +%Y%m%dT%H%M%SZ)"

# Environment checks. Other accounts besides root can be configured to run these commands.
# You'll need to modify this block if that's the case.
if ! command -v pveversion > /dev/null; then
    printf "[*]WARNING: This script is intended for use on Proxmox. Exiting.\n"
    exit 1
fi
if [[ "$EUID" -ne 0 ]]; then
    printf "[*]ERROR: This script should run as root, or an equivalent account. Exiting.\n"
    exit 1
fi

# Capture running VMs before shutdown
RUNNING_VMS=$(/usr/sbin/qm list | awk 'NR>1 && $3=="running" {print $1}')
if [[ -z "$RUNNING_VMS" ]]; then
    printf "[*]WARNING: No running VMs. Exiting.\n"
    exit 0
fi

# Graceful shutdown in parallel, this does not force-off VMs
# without a qemu-guest-agent, we'll confirm if any are left running
# in the next step.
for vmid in $RUNNING_VMS; do
    printf "[>]Shutting down vmid: %s\n" "${vmid}"
    /usr/sbin/qm shutdown "$vmid" --timeout 300 &
done
wait

# Confirm all VM's shutdown gracefully, else we bail here.
FAILED=()
for vmid in $RUNNING_VMS; do
    status=$(/usr/sbin/qm status "$vmid" --verbose 2>/dev/null | awk '/^status:/{print $2}')
    [[ "$status" != "stopped" ]] && FAILED+=("$vmid")
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    printf "[*]ERROR: VMs still running: %s, aborting snapshot automation.\n" "${FAILED[*]}" >&2
    exit 1  # systemd sees failure, blocks reboot service
fi

# Snapshot + prune each VM (if all are now offline)
for vmid in $RUNNING_VMS; do
    printf "[>]Taking snapshot: %s for vmid: %s...\n" "${SNAPSHOT_NAME}" "${vmid}"
    /usr/sbin/qm snapshot "$vmid" "$SNAPSHOT_NAME"

    # Match on our exact auto-snapshot pattern in awk, to only prune those.
    # e.g. auto_202060102T030405Z
    # There's a small chance we match on unrelated snapshots ending with that string.
    # Proxmox enforces character restrictions on snapshot names (e.g. no spaces)
    # so our xargs line below should not ingest bad strings from awk.
    # The xargs -I{<string>} argument can use any <string> for a placeholder.
    # https://www.shellcheck.net/wiki/SC1083
    printf "[>]Pruning automated snapshots down to the most recent %s for vmid %s...\n" "${KEEP_SNAPSHOTS}" "${vmid}"
    /usr/sbin/qm listsnapshot "$vmid" \
        | awk '/'"$LABEL_SNAPSHOTS"'_[0-9]{8}T[0-9]{6}Z/{print $2}' \
        | sort \
        | head -n "-${KEEP_SNAPSHOTS}" \
        | xargs -r -I'{SNAPSHOT}' /usr/sbin/qm delsnapshot "$vmid" '{SNAPSHOT}'
done

# Note the /run/reboot-required signal is mainly an Ubuntu default. Instead,
# installing and using needrestart on other Debian-family distros seems to
# be the easiest way to automate detecting this without us searching for kernel
# versions on the filesystem vs the running kernel. Ansible should handle this,
# or you should manually, outside of this script.
if ! command -v needrestart > /dev/null; then
    printf "[*]WARNING: Missing the 'needrestart' package. This script relies on that to detect pending upgrades. Exiting.\n"
    exit 1
fi
# Boot the VMs back up if a reboot isn't pending, great for weekly snapshots.
# https://github.com/liske/needrestart/blob/master/README.batch.md
KSTA=$(needrestart -b -k 2>/dev/null | awk -F': ' '/^NEEDRESTART-KSTA/{print $2}')
if [[ "${KSTA}" -eq "1" ]]; then
    # No pending upgrade, safe to resume the VMs.
    for vmid in $RUNNING_VMS; do
        printf "[>]Starting %s...\n" "${vmid}"
        /usr/sbin/qm start "$vmid" &
    done
    wait
elif [[ "${KSTA}" -eq "0" ]]; then
    # 0 is reserved for "unknown" or a failure to detect the kernel state.
    printf "[*]ERROR: needrestart failed to detect the kernel state. Exiting.\n"
    exit 1
elif [[ "${KSTA}" -eq "2" ]] || [[ "${KSTA}" -eq "3" ]]; then
    # 2 is for ABI upgrades, while 3 is for version upgrades, these are effectively
    # the /run/reboot-required signal.
    printf "[*]Pending hypervisor reboot, VMs will reboot with host.\n"
else
    printf "[*]ERROR: Unexpected NEEDRESTART-KSTA value: %s. Exiting.\n" "${KSTA}" >&2
    exit 1
fi

printf "[*]pve-maintenance complete.\n"
