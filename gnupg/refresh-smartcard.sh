#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 straysheep-dev
# Assisted-by: claude-sonnet-5

# refresh-smartcard.sh

# Run this anytime the yubikey has issues signing or authenticating
# https://github.com/drduh/YubiKey-Guide#switching-between-two-or-more-yubikeys

printf '[*]Stopping gpg-agent, ssh-agent, and pinentry...\n'
gpgconf --kill gpg-agent 2>/dev/null   # pkill alone doesn't work here.
pkill ssh-agent 2>/dev/null
pkill pinentry 2>/dev/null

printf '[*] Relaunching gpg-agent...\n'
#eval $(gpg-agent --daemon --enable-ssh-support)
gpgconf --launch gpg-agent

printf '[*] Reconnecting card to gpg-agent...\n'
gpg-connect-agent "scd serialno" "learn --force" /bye
gpg-connect-agent updatestartuptty /bye

# Previously this script didn't actually inject the variable into the shell session,
# that has to happen via a sourced bashrc or similar file to persist. This alerts on
# a missing SSH_AUTH_SOCK value.
expected_sock="$(gpgconf --list-dirs agent-ssh-socket)"
if [[ "$SSH_AUTH_SOCK" != "$expected_sock" ]]; then
    printf '[!] SSH_AUTH_SOCK mismatch; confirm bashrc or similar file is exporting it. \n'
    printf '    Current:  %s\n' "$SSH_AUTH_SOCK"
    printf '    Expected: %s\n' "$expected_sock"
else
    printf '[*] SSH_AUTH_SOCK OK: %s\n' "$SSH_AUTH_SOCK"
fi

ssh-add -L
