#!/usr/bin/env bash
# Install Wazuh agent on a Linux node and enroll with the manager
# Usage: ./install-agent.sh <manager_ip> [agent_name]
#
# Run on each node: nova (10.1.1.21), mira (10.1.1.22), orin (10.1.1.23)

set -euo pipefail

MANAGER_IP="${1:?Usage: $0 <manager_ip> [agent_name]}"
AGENT_NAME="${2:-$(hostname)}"
WAZUH_VERSION="4.9.2-1"

echo "=== Installing Wazuh agent ${WAZUH_VERSION} ==="
echo "Manager: ${MANAGER_IP}"
echo "Agent name: ${AGENT_NAME}"

# Add Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring \
    --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
    | tee /etc/apt/sources.list.d/wazuh.list

apt-get update -qq

# Install agent
WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_NAME="$AGENT_NAME" \
    apt-get install -y wazuh-agent="$WAZUH_VERSION"

# Enable and start
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

# Verify enrollment
sleep 5
if systemctl is-active --quiet wazuh-agent; then
    echo "=== Agent installed and running ==="
    echo "Enrolled as: $AGENT_NAME"
else
    echo "ERROR: Agent failed to start"
    journalctl -u wazuh-agent --no-pager -n 20
    exit 1
fi
