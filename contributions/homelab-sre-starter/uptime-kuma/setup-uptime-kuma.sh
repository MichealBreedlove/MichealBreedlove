#!/usr/bin/env bash
# Deploy Uptime Kuma for web-based status page
# Usage: ./setup-uptime-kuma.sh [--port 3001] [--data-dir /opt/uptime-kuma]

set -euo pipefail

PORT="${PORT:-3001}"
DATA_DIR="${DATA_DIR:-/opt/uptime-kuma}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) PORT="$2"; shift 2 ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        *) echo "Usage: $0 [--port 3001] [--data-dir /opt/uptime-kuma]"; exit 1 ;;
    esac
done

echo "=== Deploying Uptime Kuma ==="
echo "Port: $PORT"
echo "Data: $DATA_DIR"

mkdir -p "$DATA_DIR"

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is required. Install with: apt install docker.io" >&2
    exit 1
fi

# Stop existing container if running
docker rm -f uptime-kuma 2>/dev/null || true

# Deploy Uptime Kuma
docker run -d \
    --name uptime-kuma \
    --restart always \
    -p "$PORT:3001" \
    -v "$DATA_DIR:/app/data" \
    louislam/uptime-kuma:1

echo ""
echo "=== Uptime Kuma is running ==="
echo "Dashboard: http://$(hostname -I | awk '{print $1}'):${PORT}"
echo ""
echo "Next steps:"
echo "  1. Open the dashboard URL and create your admin account"
echo "  2. Add monitors for your services (see uptime-kuma-monitors.json)"
echo "  3. Create a status page under Settings > Status Pages"
