#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 straysheep-dev

# shellcheck disable=SC2034
# shellcheck disable=SC2016

# Built using Claude Opus 4.6 as a linter and research tool. Otherwise these commands mirror the
# essentials detailed in Wazuh's upgrade documentation. Version-specific functions are noted
# below as TODO: items.

# Wazuh Standalone (All-in-One) Upgrade Script
# Based on: https://documentation.wazuh.com/current/upgrade-guide/upgrading-central-components.html
#
# Requirements:
# - Single-node deployment (indexer, manager, dashboard on same host)
# - Running as a user that can access and decrypt the SOPS YAML file(s)
# 	- If running as root via cron, ensure root can resolve those variables or change where these files are stored
# - Looks for the SOPS file under $HOME/.config/wazuh/environment.enc.yaml by default, so ~/.config/wazuh needs created if left as the default
# - https://github.com/getsops/sops?tab=readme-ov-file#passing-secrets-to-other-processes
# - The SOPS secret file must have the following vars:
#   - wazuh_admin_user: <admin_user>
#   - wazuh_admin_password: <admin_password>
#   - wazuh_api: https://<wazuh_api>:9200
#
# Run this weekly or daily as part of normal system maintenance
#
# Cron Example (run as root):
# PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin/:/sbin
# m h  dom mon dow   command
# 0 0 * * 1 /bin/bash /usr/local/bin/update-wazuh.sh

set -euo pipefail

# Colors
BLUE="\033[01;34m"
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
RED="\033[01;31m"
BOLD="\033[01;01m"
RESET="\033[00m"

# Variables
WAZUH_UPGRADE_LOG_FILE=/var/log/wazuh-upgrade.log
WAZUH_CURRENT_VERSION="$(apt-cache policy wazuh-manager | awk '/Installed:/{print $2}' | cut -d '-' -f 1)"
WAZUH_LATEST_VERSION="$(apt-cache policy wazuh-manager | awk '/Candidate:/{print $2}' | cut -d '-' -f 1)"
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"  # https://github.com/getsops/sops?tab=readme-ov-file#23encrypting-using-age
SOPS_SECRET_FILE="$HOME/.config/wazuh/environment.enc.yaml"
WAZUH_USER=$(sops -d --extract '["wazuh_admin_user"]' "$SOPS_SECRET_FILE")
WAZUH_PASS=$(sops -d --extract '["wazuh_admin_password"]' "$SOPS_SECRET_FILE")
WAZUH_API=$(sops -d --extract '["wazuh_api"]' "$SOPS_SECRET_FILE")
# Here ingesting secrets as environment variables vs using sops exec-env ... is done for two reasons:
# - It's a similar threat model, sops exec-env processes are shorter-lived, but still can be recorded by things like pspy
# - Using sops requires single quoting the new process command string, this creates challenges with quoting and variables
# - Both options keep secrets out of the shell history
# - If a rogue process can read shell history, we have a bigger problem than just protecting local secrets

# Helper function to standardize curl usage
api_call() {
  curl -sS -k -u "${WAZUH_USER}:${WAZUH_PASS}" "$@"
}

pre_upgrade() {
	# Confirm we actually need to upgrade
	if [[ "$WAZUH_CURRENT_VERSION" == "$WAZUH_LATEST_VERSION" ]]
	then
		echo -e "[${BLUE}*${RESET}] ${BOLD}Installed version (v${WAZUH_CURRENT_VERSION}) is the latest candidate, nothing to upgrade.${RESET}"
		exit 0
	fi

	# Create the log file if it doesn't exist
	if ! [[ -f "${WAZUH_UPGRADE_LOG_FILE}" ]]
	then
		sudo touch "${WAZUH_UPGRADE_LOG_FILE}"
		sudo chown root:root "${WAZUH_UPGRADE_LOG_FILE}"
		sudo chmod 600 "${WAZUH_UPGRADE_LOG_FILE}"
	fi

	echo -e "[${GREEN}>${RESET}]Starting upgrade from ${BLUE}${WAZUH_CURRENT_VERSION}${RESET} to ${BLUE}${WAZUH_LATEST_VERSION}${RESET} on ${BOLD}$(date -Ins)...${RESET}"

	# TODO: Additional checking of WAZUH_ variables here before obtaining HTTP_CODE

	HTTP_CODE="$(api_call -w '%{http_code}' "${WAZUH_API}/_cluster/health?pretty" -o /dev/null 2>/dev/null)"
	if [[ $HTTP_CODE == "200" ]]
	then
		echo -e "[${BLUE}*${RESET}]${BOLD}Credentials decrypted successfully.${RESET}"
	else
		echo -e "[${BLUE}*${RESET}]${BOLD}Failed to decrypt SOPS data. Exiting.${RESET}"
		exit 1
	fi

	# Stop necessary services
	echo -e "[${BLUE}*${RESET}]Stopping Filebeat and Wazuh Dashboard...${RESET}"
	sudo systemctl stop filebeat
	sudo systemctl stop wazuh-dashboard
}

upgrade_indexer() {
	# Upgrade wazuh-indexer
	# https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#preparing-the-wazuh-indexer-cluster-for-upgrade
	echo -e "[${GREEN}>${RESET}]${BOLD}Upgrading wazuh-indexer...${RESET}"

	## 1. Backup the existing Wazuh indexer security configuration files:
	echo -e "[${BLUE}*${RESET}]${BOLD}Backing up indexer security configuration...${RESET}"
	sudo /usr/share/wazuh-indexer/bin/indexer-security-init.sh --options "-backup /etc/wazuh-indexer/opensearch-security -icl -nhnv"

	## 2. Disable shard replication to prevent shard replicas from being created while Wazuh indexer nodes are being taken offline for the upgrade.
	echo -e "[${BLUE}*${RESET}]${BOLD}Disabling shard replication...${RESET}"
	api_call -X PUT "${WAZUH_API}/_cluster/settings" \
	-H 'Content-Type: application/json' \
	-d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}'

	## 3. Perform a flush operation on the cluster to commit transaction log entries to the index
	echo -e "[${BLUE}*${RESET}]${BOLD}Flushing index data...${RESET}"
	api_call -X POST "${WAZUH_API}/_flush"

	## 4. Run the following command on the Wazuh manager node(s) if running a single-node Wazuh indexer cluster.
	echo -e "[${BLUE}*${RESET}]${BOLD}Stopping Wazuh Manager...${RESET}"
	sudo systemctl stop wazuh-manager

	## 5. Stop the Wazuh indexer service.
	echo -e "[${BLUE}*${RESET}]${BOLD}Stopping wazuh-indexer...${RESET}"
	sudo systemctl stop wazuh-indexer

	## 6. Backup the /etc/wazuh-indexer/jvm.options file to preserve your custom JVM settings
	sudo cp /etc/wazuh-indexer/jvm.options /etc/wazuh-indexer/jvm.options.bkup

	## 7. Upgrade indexer package
	echo -e "[${BLUE}*${RESET}]${BOLD}Upgrading wazuh-indexer package...${RESET}"
	sudo apt update -q
	DEBIAN_FRONTEND=noninteractive \
		NEEDRESTART_MODE=l \
		sudo apt install -y \
		-o Dpkg::Options::='--force-confdef' \
		-o Dpkg::Options::='--force-confnew' \
		wazuh-indexer

	echo -e "[${YELLOW}i${RESET}]${BOLD}Manually reapply any custom settings from${RESET} ${YELLOW}/etc/wazuh-indexer/jvm.options.bkup${RESET} -> ${YELLOW}/etc/wazuh-indexer/jvm.options${RESET} ${BOLD}if needed.${RESET}"

	## 8. Restart indexer
	echo -e "[${BLUE}*${RESET}]${BOLD}Restarting Wazuh Indexer...${RESET}"
	sudo systemctl daemon-reload
	sudo systemctl enable wazuh-indexer
	sudo systemctl start wazuh-indexer
	### Wait for indexer to become active again
	echo -e "[${BLUE}*${RESET}]${BOLD}Waiting for wazuh-indexer...${RESET}"
	for ((i=1; i<30; i++)); do
		if systemctl is-active -q wazuh-indexer
		then
			break
		fi
		sleep 2
		echo -e "    [${BLUE}*${RESET}]Attempt $i...${RESET}"
	done

	### Catch a failed state
	if ! systemctl is-active -q wazuh-indexer
	then
		echo -e "[${BLUE}*${RESET}]${RED}ERROR, wazuh-indexer failed to start. Exiting.${RESET}"
		exit 1
	fi

	# Post Indexer Upgrade Actions
	# https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#post-upgrade-actions

	## 1. Re-apply security configuration
	echo -e "[${BLUE}*${RESET}]${BOLD}Applying backed-up security configuration...${RESET}"
	echo -e "[${YELLOW}i${RESET}]${YELLOW}NOTE: Retrieving the cluster state can take a few minutes, it will continue until it succeeds.${RESET}"
	sudo /usr/share/wazuh-indexer/bin/indexer-security-init.sh

	## 2. Verify node is in cluster
	echo -e "[${BLUE}*${RESET}]${BOLD}Verifying indexer cluster nodes...${RESET}"
	api_call "${WAZUH_API}/_cat/nodes?v"

	## 3. Re-enable shard allocation
	echo -e "[${BLUE}*${RESET}]${BOLD}Re-enabling shard allocation...${RESET}"
	api_call -X PUT "${WAZUH_API}/_cluster/settings" \
	-H 'Content-Type: application/json' \
	-d '{"persistent":{"cluster.routing.allocation.enable":"all"}}'

	## 4. Verify cluster health
	echo -e "[${BLUE}*${RESET}]${BOLD}Cluster health:${RESET}"
	api_call "${WAZUH_API}/_cat/health?v"

	# TODO: Check and update plugins
	# sudo /usr/share/wazuh-indexer/bin/opensearch-plugin list
	# In the output, plugins that require an update will be labeled as "outdated".
	# sudo /usr/share/wazuh-indexer/bin/opensearch-plugin remove <PLUGIN_NAME>
	# sudo /usr/share/wazuh-indexer/bin/opensearch-plugin install <PLUGIN_NAME>
}

upgrade_manager() {
	# Upgrade wazuh-manager
	# https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#upgrading-the-wazuh-server
	echo -e "[${GREEN}>${RESET}]${BOLD}Upgrading the Wazuh Manager components...${RESET}"

	## 1. Upgrade wazuh-manager
	## If the /var/ossec/etc/ossec.conf configuration file was modified, it will not be replaced by the upgrade.
	## You will therefore have to add the settings of the new capabilities manually. More information can be
	## found in the User manual. https://documentation.wazuh.com/4.14/user-manual/index.html
	DEBIAN_FRONTEND=noninteractive \
		NEEDRESTART_MODE=l \
		sudo apt install -y \
		-o Dpkg::Options::='--force-confdef' \
		-o Dpkg::Options::="--force-confold" \
		wazuh-manager

	## 2. Start manager
	echo -e "[${BLUE}*${RESET}]${BOLD}Starting Wazuh Manager...${RESET}"
	sudo systemctl daemon-reload
	sudo systemctl enable wazuh-manager
	sudo systemctl start wazuh-manager

	## Configuring CDB lists
	## When upgrading from Wazuh 4.12.x or earlier, follow these steps to configure the newly added CDB lists.
	## https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-cdb-lists

	## Configuring the vulnerability detection and indexer connector
	## If upgrading from version 4.8.x or later, skip the vulnerability detection and indexer connector configurations
	## and proceed to Configuring Filebeat. No action is needed as the vulnerability detection and indexer connector blocks
	## are already configured.
	## When upgrading from Wazuh version 4.7.x or earlier, follow these steps to configure the vulnerability detection and
	## indexer connector blocks.
	## https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-the-vulnerability-detection-and-indexer-connector
}

upgrade_filebeat() {
	# Configure Filebeat
	# https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#configuring-filebeat
	# When upgrading Wazuh, you must also update the Wazuh Filebeat module and the alerts template to ensure
	# compatibility with the latest Wazuh indexer version. Follow these steps to configure Filebeat properly.

	## 1. Download the Wazuh module for Filebeat
	echo -e "[${BLUE}*${RESET}]${BOLD}Downloading latest Wazuh Filebeat module from${RESET} ${BLUE}https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.5.tar.gz${RESET}..."
	curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.5.tar.gz | \
	sudo tar -xz -C /usr/share/filebeat/module

	## 2. Download the alerts template
	echo -e "[${BLUE}*${RESET}]${BOLD}Downloading latest alerts template from${RESET} ${BLUE}https://raw.githubusercontent.com/wazuh/wazuh/v${WAZUH_LATEST_VERSION}/extensions/elasticsearch/7.x/wazuh-template.json${RESET}..."
	sudo curl -so /etc/filebeat/wazuh-template.json \
		"https://raw.githubusercontent.com/wazuh/wazuh/v${WAZUH_LATEST_VERSION}/extensions/elasticsearch/7.x/wazuh-template.json"
	sudo chmod go+r /etc/filebeat/wazuh-template.json

	## 3. Backup Filebeat config
	echo -e "[${BLUE}*${RESET}]${BOLD}Backing up${RESET} ${YELLOW}/etc/filebeat/filebeat.yml${RESET} -> ${YELLOW}/etc/filebeat/filebeat.yml.bkup${RESET}..."
	sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bkup

	## 4. Upgrade Filebeat
	echo -e "[${BLUE}*${RESET}]${BOLD}Upgrading Filebeat...${RESET}"
	DEBIAN_FRONTEND=noninteractive \
		NEEDRESTART_MODE=l \
		sudo apt-get install -y \
		-o Dpkg::Options::='--force-confdef' \
		-o Dpkg::Options::='--force-confnew' \
		filebeat

	## 5. Restore Filebeat config
	echo -e "[${BLUE}*${RESET}]${BOLD}Restoring Filebeat config...${RESET}"
	sudo cp /etc/filebeat/filebeat.yml.bkup /etc/filebeat/filebeat.yml

	## 6. Restart Filebeat
	echo -e "[${BLUE}*${RESET}]${BOLD}Restarting Filebeat...${RESET}"
	sudo systemctl daemon-reload
	sudo systemctl enable filebeat
	sudo systemctl start filebeat

	## 7. Upload new template and pipelines
	echo -e "[${BLUE}*${RESET}]${BOLD}Setting up Filebeat pipelines and index management...${RESET}"
	sudo filebeat setup --pipelines
	sudo filebeat setup --index-management -E output.logstash.enabled=false

	## 8. TODO
	## If you are upgrading from Wazuh versions v4.8.x or v4.9.x, manually update the wazuh-states-vulnerabilities-*
	## mappings using the following command. Replace <WAZUH_INDEXER_IP_ADDRESS>, <USERNAME>, and <PASSWORD> with the
	## values applicable to your deployment.
}

upgrade_dashboard() {
	# Upgrade the Wazuh Dashboard
	# https://documentation.wazuh.com/4.14/upgrade-guide/upgrading-central-components.html#upgrading-the-wazuh-dashboard
	echo -e "[${GREEN}>${RESET}]${BOLD}Upgrading the Wazuh Dashboard...${RESET}"

	## 1. Backup dashboard config
	echo -e "[${GREEN}>${RESET}]${BOLD}Backing up${RESET} ${BLUE}/etc/wazuh-dashboard/opensearch_dashboards.yml${RESET} -> ${BLUE}/etc/wazuh-dashboard/opensearch_dashboards.yml.bkup${RESET}..."
	sudo cp /etc/wazuh-dashboard/opensearch_dashboards.yml \
	/etc/wazuh-dashboard/opensearch_dashboards.yml.bkup

	## 2. Upgrade wazuh-dashboard
	DEBIAN_FRONTEND=noninteractive \
		NEEDRESTART_MODE=l \
		sudo apt-get install -y \
		-o Dpkg::Options::='--force-confdef' \
		-o Dpkg::Options::='--force-confnew' \
		wazuh-dashboard

	## 3. Reapply custom dashboard settings
	echo -e "[${YELLOW}i${RESET}]${BOLD}Manually reapply any configuration changes to the ${BLUE}/etc/wazuh-dashboard/opensearch_dashboards.yml${RESET} ${BOLD}file.${RESET}"
	echo -e "[${YELLOW}i${RESET}]${BOLD}Ensure that the values of${RESET} ${YELLOW}server.ssl.key${RESET} and ${YELLOW}server.ssl.certificate${RESET} ${BOLD}match the files located in${RESET} ${BLUE}/etc/wazuh-dashboard/certs/${RESET}."
	echo -e ""
	echo -e "[${YELLOW}i${RESET}]${BOLD}If you are upgrading from Wazuh versions 4.7 and earlier, ensure the value of${RESET} ${GREEN}uiSettings.overrides.defaultRoute${RESET}"
	echo -e "   ${BOLD}in the ${RESET}${BLUE}/etc/wazuh-dashboard/opensearch_dashboards.yml${RESET} ${BOLD}file is set to /app/wz-home as shown below:${RESET}"
	echo -e ""
	echo -e "    ${GREEN}uiSettings.overrides.defaultRoute${RESET}: ${BLUE}/app/wz-home${RESET}"

	## TODO: Check and update plugins
	## sudo -u wazuh-dashboard /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin list
	## In the output, plugins that require an update will be labeled as "outdated".
	## Upgeade plugins by reinstalling them:
	## sudo -u wazuh-dashboard /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin remove <PLUGIN_NAME>
	## sudo -u wazuh-dashboard /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin install <PLUGIN_NAME>

	## 4. Restart dashboard
	echo -e "[${BLUE}*${RESET}]Restarting Wazuh Dashboard..."
	sudo systemctl daemon-reload
	sudo systemctl enable wazuh-dashboard
	sudo systemctl start wazuh-dashboard
}

post_upgrade() {
	## TODO: Pin Wazuh packages / freeze upgrades so this script is the only mechanism to update them
	## This is likely more important in a distributed cluster vs an all-in-one virtual machine with
	## snapshots.

	# Print version info for logging
	echo -e "[${GREEN}>${RESET}]${BOLD}Listing installed versions...${RESET}"
	apt list --installed wazuh-indexer
	apt list --installed wazuh-manager
	apt list --installed wazuh-dashboard

	# Check Wazuh health
	echo -e "[${BLUE}i${RESET}]${BOLD}Indexer cluster status:${RESET}"
	api_call "${WAZUH_API}/_cat/health?v"

	# Log completion time
	echo -e "[${GREEN}>${RESET}]Completed upgrade from ${BLUE}${WAZUH_CURRENT_VERSION}${RESET} to ${BLUE}${WAZUH_LATEST_VERSION}${RESET} on ${BOLD}$(date -Ins)...${RESET}"

	# Cleanup environment variables
	unset WAZUH_USER WAZUH_PASS WAZUH_API
}

main() {
	pre_upgrade
	upgrade_indexer
	upgrade_manager
	upgrade_filebeat
	upgrade_dashboard
	post_upgrade
}

main 2>&1 | sudo tee -a "${WAZUH_UPGRADE_LOG_FILE}"
exit "${PIPESTATUS[0]}"
# PIPESTATUS is a shell variable in bash. The bash manual details what it does and how it works:
#     An array variable (see Arrays below) containing a list of exit status values from the processes in
#     the most-recently-executed foreground pipeline (which may contain only a single command)
# See: https://unix.stackexchange.com/questions/14270/get-exit-status-of-process-thats-piped-to-another
