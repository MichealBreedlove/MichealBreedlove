# Uptime Kuma Integration Guide

Connect your homelab health checks to [Uptime Kuma](https://github.com/louislam/uptime-kuma) for a web-based status page.

## Quick Start

```bash
# Deploy Uptime Kuma (requires Docker)
./setup-uptime-kuma.sh --port 3001

# Access the dashboard
open http://<your-ip>:3001
```

## Setup

### 1. Deploy Uptime Kuma

Run the setup script on any node with Docker (recommended: monitoring CT on Mira):

```bash
./setup-uptime-kuma.sh --port 3001 --data-dir /opt/uptime-kuma
```

Or deploy manually with Docker Compose:

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    restart: always
    ports:
      - "3001:3001"
    volumes:
      - /opt/uptime-kuma:/app/data
```

### 2. Create Admin Account

Open the dashboard at `http://<host>:3001` and create your admin account on first visit.

### 3. Add Monitors

Add monitors for each service. Reference configurations are in `uptime-kuma-monitors.json`.

**HTTP monitors** (for web services):
- Plex: `http://plex.local:32400/web`
- TrueNAS: `http://nas.local/api/v2.0/system/state`
- Grafana: `http://10.1.1.25:3000/api/health`
- Prometheus: `http://10.1.1.25:9090/-/healthy`
- Proxmox nodes: `https://10.1.1.x:8006` (enable "Ignore TLS")

**Ping monitors** (for network devices):
- OPNsense: `10.1.1.1`

**DNS monitors**:
- DNS resolution: query `example.com` against `10.1.1.1`

### 4. Connect Health Checks

Uptime Kuma supports **push monitors** — your existing `health_check.sh` can push results:

```bash
#!/usr/bin/env bash
# Add to the end of health_check.sh:

KUMA_PUSH_URL="http://<kuma-host>:3001/api/push/<monitor-token>"

if [ "$FAILURES" -eq 0 ]; then
    curl -sf "${KUMA_PUSH_URL}?status=up&msg=All+services+healthy" >/dev/null 2>&1
else
    curl -sf "${KUMA_PUSH_URL}?status=down&msg=${FAILURES}+services+down" >/dev/null 2>&1
fi
```

To get the push URL:
1. Create a new monitor with type **Push**
2. Copy the push URL from the monitor settings
3. Add the curl call to your health check script or cron job

### 5. Create Status Page

1. Go to **Status Pages** in the sidebar
2. Click **New Status Page**
3. Add your monitors grouped by category (Infrastructure, Media, Network)
4. Set the page to **Public** if you want it accessible without login
5. Access at `http://<host>:3001/status/<page-slug>`

## Integration with Existing Monitoring

Uptime Kuma complements your Prometheus + Grafana stack:

| Feature | Prometheus/Grafana | Uptime Kuma |
|---|---|---|
| Metrics collection | Deep metrics, time series | Simple up/down |
| Alerting | Alertmanager rules | Built-in notifications |
| Status page | Requires setup | Built-in, user-friendly |
| External checks | Internal only | Supports external URLs |
| Audience | Operators | Everyone (family, users) |

**Recommended setup**: Use Prometheus for detailed operational monitoring and Uptime Kuma for a simple status page visible to all homelab users.

## Notifications

Uptime Kuma supports 90+ notification services. Recommended:

- **Telegram** — Instant mobile alerts (pairs with morning brief)
- **Slack/Discord** — Channel-based team alerts
- **Email (SMTP)** — Traditional email notifications

Configure under **Settings > Notifications** in the dashboard.
