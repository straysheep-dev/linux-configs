#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 straysheep-dev
# Assisted-by: claude-sonnet-5
#
# Run with sudo if policykit prevents normal users from modifying netowrks.

set -euo pipefail

CONN_NAME='eth-security'
IFNAME='eth0'  # Change to match interface name.
nmcli connection add type ethernet con-name "$CONN_NAME" ifname "$IFNAME"

# Random MAC
nmcli connection modify "$CONN_NAME" 802-3-ethernet.cloned-mac-address "random"

# Configure DHCP
nmcli connection modify "$CONN_NAME" ipv4.method "auto"
nmcli connection modify "$CONN_NAME" ipv6.method "disabled"  # Optional, disable IPv6

# Ignore DHCP settings
nmcli connection modify "$CONN_NAME" ipv4.ignore-auto-routes yes  # Requires manual route and gateway configuration.
nmcli connection modify "$CONN_NAME" ipv6.ignore-auto-routes yes  # Requires manual route and gateway configuration.
nmcli connection modify "$CONN_NAME" ipv4.dns-search "~."
nmcli connection modify "$CONN_NAME" ipv6.dns-search "~."
nmcli connection modify "$CONN_NAME" ipv4.dhcp-send-hostname no  # NM won't accept a DHCP provided hostname if it has one already.
nmcli connection modify "$CONN_NAME" ipv6.dhcp-send-hostname no  # NM won't accept a DHCP provided hostname if it has one already.
nmcli connection modify "$CONN_NAME" ipv4.ignore-auto-dns yes
nmcli connection modify "$CONN_NAME" ipv6.ignore-auto-dns yes

# Configure Routes
GATEWAY_ADDR='192.168.122.1'
nmcli connection modify "$CONN_NAME" ipv4.routes "0.0.0.0/0 $GATEWAY_ADDR 100"  # Determine the gateway address first.

# Configure DNS
nmcli connection modify "$CONN_NAME" ipv4.dns "127.0.0.1"      # Change to Tailscale's DNS; 100.100.100.100
nmcli connection modify "$CONN_NAME" ipv6.dns "::1"            # Change to Tailscale's DNS; fd7a:115c:a1e0::53

# Disable LLMNR and mDNS
nmcli connection modify "$CONN_NAME" connection.llmnr "no"
nmcli connection modify "$CONN_NAME" connection.mdns "no"

nmcli connection up "$CONN_NAME" ifname "$IFNAME"
nmcli device status
nmcli -p con show "$CONN_NAME"  # -p "pretty" output is more readable.
