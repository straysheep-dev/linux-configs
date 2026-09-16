#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 straysheep-dev
# Assisted-by: claude-sonnet-4-6
# Assisted-by: claude-sonnet-5

# Installer script to drop RF tools onto an Ubuntu machine.

set -euo pipefail

# ========== Variables ==========
# Host vars
BUILD_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
BUILD_ARCH="$(uname -m)"
case "$BUILD_ARCH" in
    x86_64|amd64)   BUILD_ARCH="amd64" ;;
    aarch64|arm64)  BUILD_ARCH="arm64" ;;
    *) echo "[!] Unsupported arch: ${BUILD_ARCH}"; exit 1 ;;
esac
BETTERCAP_CONFIG_DIR="${HOME}/src/linux-configs/bettercap"

# This script configures remote access over an existing Tailscale connection;
# it does not install or authenticate Tailscale itself.
if ! command -v tailscale >/dev/null 2>&1; then
    echo "[!] tailscale not found. Install and authenticate tailscale first. Exiting."
    exit 1
fi
TAILSCALE_IP="$(tailscale ip -4 2>/dev/null)"
TAILSCALE_FQDN="$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')"
# TAILSCALE_CERT_DIR='/etc/bettercap/tls'
# TAILSCALE_CERT_FILE="${TAILSCALE_CERT_DIR}/tailscale.crt"
# TAILSCALE_KEY_FILE="${TAILSCALE_CERT_DIR}/tailscale.key"

# GO vars, see https://go.dev/dl/
declare -A GO_SHASUMS=(
    [amd64]="5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053"
    [arm64]="fe4789e92b1f33358680864bbe8704289e7bb5fc207d80623c308935bd696d49"
)
GO_VERSION="go1.26.5"
GO_URL="https://go.dev/dl/${GO_VERSION}.linux-${BUILD_ARCH}.tar.gz"

# Bettercap vars
BETTERCAP_REPO='https://github.com/bettercap/bettercap.git'
BETTERCAP_SRC_DIR="${HOME}/src/bettercap"
BETTERCAP_TAG="v2.41.7"
# BETTERCAP_UI_REPO='https://github.com/bettercap/ui.git'  # Not necessary, bettercap builds the UI internally now
# BETTERCAP_UI_TAG="v1.4.0"                                # Not necessary, bettercap builds the UI internally now
BETTERCAP_USER="operator"
BETTERCAP_PASS="$(tr -dc '[:alnum:]' < /dev/urandom | fold -w 32 | head -n 1)"
BETTERCAP_UI_PORT='8080'
BETTERCAP_API_PORT='8081'
CUSTOM_CAP_FILE='/usr/local/share/bettercap/caplets/operator-ui.cap'

# Caddy vars
CADDY_HTTPS_PORT="443"
CADDYFILE='/etc/caddy/Caddyfile'
CADDY_VERSION='v2.11.4'
CADDY_REPO='https://github.com/caddyserver/caddy'
CADDY_SHASUMS_TXT="${CADDY_REPO}/releases/download/${CADDY_VERSION}/caddy_${CADDY_VERSION#v}_checksums.txt"
CADDY_SHASUMS_PEM="${CADDY_REPO}/releases/download/${CADDY_VERSION}/caddy_${CADDY_VERSION#v}_checksums.txt.pem"
CADDY_SHASUMS_SIG="${CADDY_REPO}/releases/download/${CADDY_VERSION}/caddy_${CADDY_VERSION#v}_checksums.txt.sig"
CADDY_ARTIFACT_DEB="${CADDY_REPO}/releases/download/${CADDY_VERSION}/caddy_${CADDY_VERSION#v}_${BUILD_OS}_${BUILD_ARCH}.deb"
CADDY_SAN_URL="${CADDY_REPO}/.github/workflows/release.yml@refs/tags/${CADDY_VERSION}"
CADDY_SAN_ISSUER='https://token.actions.githubusercontent.com'

# Create necessary paths
mkdir -p ~/Downloads
mkdir -p ~/src

# ========== Install Apt Dependencies ==========
# wireless-tools does not exist on 26.04.
# usbguard and apparmor help harden the internal and physical system.
sudo apt update
sudo apt install -y \
    iw \
    jq \
    usbguard \
    apparmor-profiles \
    apparmor-profiles-extra \
    net-tools \
    wireless-tools

# ========== Install GO ==========
INSTALLED_GO_VERSION=""
if command -v go >/dev/null 2>&1; then
    INSTALLED_GO_VERSION=$(go version | awk '{print $3}')
fi

if [[ "${INSTALLED_GO_VERSION}" != "${GO_VERSION}" ]]; then
    cd ~/Downloads || exit 1
    wget "${GO_URL}"
    COMPUTED_SHASUM="$(sha256sum "${GO_VERSION}.linux-${BUILD_ARCH}.tar.gz" | awk '{print $1}')"
    if [[ "${COMPUTED_SHASUM}" != "${GO_SHASUMS[$BUILD_ARCH]}" ]]; then
        echo "[!] Checksum mismatch. Exiting."
        exit 1
    fi

    # Unpack and place the current go binary
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "${GO_VERSION}.linux-${BUILD_ARCH}.tar.gz"

    # Add /usr/local/go/bin to your $PATH
    if ! [[ -f /etc/profile.d/golang.sh ]]; then
        echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh >/dev/null
        source /etc/profile.d/golang.sh
    fi

    # Verify go is installed
    if ! go version; then
        echo "GO not installed. Exiting."
        exit 1
    fi
else
    echo "[*] ${GO_VERSION} already installed, skipping."
fi

# ========== Install Bettercap ==========
INSTALLED_BETTERCAP_VERSION=""
if command -v bettercap >/dev/null 2>&1; then
    INSTALLED_BETTERCAP_VERSION="$(bettercap --version | awk '{print $2}')"
fi

if [[ "${INSTALLED_BETTERCAP_VERSION}" != "${BETTERCAP_TAG}" ]]; then
    sudo apt update
    sudo apt install -y pkg-config libpcap-dev libusb-1.0-0-dev libnetfilter-queue-dev build-essential

    cd ~/src || exit 1
    git clone --branch "${BETTERCAP_TAG}" --depth 1 "${BETTERCAP_REPO}"
    cd "${BETTERCAP_SRC_DIR}" || exit 1

    make build
    sudo make install

    if ! bettercap --version; then
        echo "Bettercap failed to install. Exiting."
        exit 1

    fi
else
    echo "[*] bettercap ${BETTERCAP_TAG} already installed, skipping."
fi

# ========== Configure Remote Access ==========
# Install cosign
go install github.com/sigstore/cosign/v3/cmd/cosign@latest

# Download caddy checksums txt, pem, and sig files
curl -LfO "${CADDY_SHASUMS_TXT}"
curl -LfO "${CADDY_SHASUMS_PEM}"
curl -LfO "${CADDY_SHASUMS_SIG}"

# Download caddy release file
curl -LfO "${CADDY_ARTIFACT_DEB}"

# Confirm signature
COSIGN_EXPERIMENTAL=1 ~/go/bin/cosign verify-blob \
    --certificate "${CADDY_SHASUMS_PEM##*/}" \
    --signature "${CADDY_SHASUMS_SIG##*/}" \
    --certificate-identity "${CADDY_SAN_URL}" \
    --certificate-oidc-issuer "${CADDY_SAN_ISSUER}" \
    "${CADDY_SHASUMS_TXT##*/}"

# Confirm checksum
sha512sum -c "${CADDY_SHASUMS_TXT##*/}" --ignore-missing

# Install caddy from .deb file via apt
sudo apt install -y ./"${CADDY_ARTIFACT_DEB##*/}"

# Config templates below live in this repo's bettercap/ dir, not the cloned
# upstream bettercap source (${BETTERCAP_SRC_DIR}).
if [[ ! -d "${BETTERCAP_CONFIG_DIR}" ]]; then
    echo "[!] ${BETTERCAP_CONFIG_DIR} not found. Exiting."
    exit 1
fi

# Apply Caddyfile
sudo install -m 644 "${BETTERCAP_CONFIG_DIR}/Caddyfile" "${CADDYFILE}"
sudo sed -i \
  -e "s|__TAILSCALE_FQDN__|${TAILSCALE_FQDN}|g" \
  -e "s|__TAILSCALE_IP__|${TAILSCALE_IP}|g" \
  -e "s|__BETTERCAP_UI_PORT__|${BETTERCAP_UI_PORT}|g" \
  -e "s|__BETTERCAP_API_PORT__|${BETTERCAP_API_PORT}|g" \
  "${CADDYFILE}"

# Permit Caddy Tailscale certificate access
if ! grep -iq 'TS_PERMIT_CERT_UID=caddy' /etc/default/tailscaled; then
    echo 'TS_PERMIT_CERT_UID=caddy' | sudo tee -a  /etc/default/tailscaled >/dev/null
fi

# Override Caddy default systemd service file, to ensure it waits for Tailscale.
sudo install -m 644 "${BETTERCAP_CONFIG_DIR}/override.conf" /etc/systemd/system/caddy.service.d/override.conf

sudo systemctl daemon-reload
sudo systemd-analyze verify caddy.service
sudo systemctl restart tailscaled caddy

# ========== Configure Bettercap ==========
sudo bettercap -eval "caplets.update; q"  # You no longer need to run "ui.update"

# /usr/local/share/bettercap/caplets/operator-ui.cap
# Custom minimal caplet
# http-ui.cap / https-ui.cap are no longer used for the web UI.
# All values below get injected by the install script.
sudo install -m 600 -o root -g root /dev/null "${CUSTOM_CAP_FILE}"
echo 'set ui.address 127.0.0.1
set ui.port __BETTERCAP_UI_PORT__
set api.rest.port __BETTERCAP_API_PORT__
set api.rest.address 127.0.0.1
set api.rest.username __BETTERCAP_USER__
set api.rest.password __BETTERCAP_PASS__
#set api.rest.certificate /etc/bettercap/tls/tailscale.crt
#set api.rest.key /etc/bettercap/tls/tailscale.pem

set events.stream.output /var/log/bettercap.log

ui on' | sudo tee "${CUSTOM_CAP_FILE}" >/dev/null

sudo sed -i \
  -e "s|__BETTERCAP_UI_PORT__|${BETTERCAP_UI_PORT}|g" \
  -e "s|__BETTERCAP_API_PORT__|${BETTERCAP_API_PORT}|g" \
  -e "s|__BETTERCAP_USER__|${BETTERCAP_USER}|g" \
  -e "s|__BETTERCAP_PASS__|${BETTERCAP_PASS}|g" \
  "${CUSTOM_CAP_FILE}"

# UFW rules
sudo ufw --force enable
sudo ufw allow in on tailscale0 to any proto tcp port "${CADDY_HTTPS_PORT}" from 100.64.0.0/10 comment 'caddy'

# Install the service file
sudo install -m 644 "${BETTERCAP_CONFIG_DIR}/bettercap.service" /etc/systemd/system/bettercap.service

sudo systemctl daemon-reload
sudo systemctl enable --now bettercap.service

# ========== Install aircrack-ng ==========
# TODO

# ========== Install mdk4 ==========
# TODO

# ========== Install relay tools (berate_ap/wpa_sycophant/eaphammer) ==========
# TODO

# ========== Install airhammer ==========
# TODO

# ========== Install WHAD + Morpho ==========
# TODO
