#!/usr/bin/env python3
"""Multi-channel alert router for burn-rate alerts.

Routes SLO burn-rate alerts to Alertmanager, Slack, and email based on
severity and alert routing rules.

Usage:
    python alert_router.py --config alert_routing.json --alert <alert_json>
    python alert_router.py --config alert_routing.json --stdin

Config (alert_routing.json):
    {
      "channels": {
        "alertmanager": { "url": "http://10.1.1.25:9093" },
        "slack": { "webhook_url": "https://hooks.slack.com/..." },
        "email": { "smtp_host": "...", "smtp_port": 587, ... }
      },
      "routes": [
        { "severity": "critical", "channels": ["alertmanager", "slack", "email"] },
        { "severity": "warning",  "channels": ["alertmanager", "slack"] },
        { "severity": "info",     "channels": ["slack"] }
      ]
    }
"""

import argparse
import json
import os
import smtplib
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path


def load_config(path):
    with open(path) as f:
        return json.load(f)


def determine_severity(alert):
    """Determine alert severity from burn rate values."""
    burn_rate = alert.get("burn_rate", 0)
    if burn_rate >= 10:
        return "critical"
    elif burn_rate >= 3:
        return "warning"
    return "info"


def get_routes(config, severity):
    """Get the channels to route to for a given severity."""
    for route in config.get("routes", []):
        if route["severity"] == severity:
            return route.get("channels", [])
    return []


# --- Channel implementations ---

def send_alertmanager(config, alert, severity):
    """Push alert to Alertmanager via its HTTP API."""
    am_config = config["channels"].get("alertmanager", {})
    url = am_config.get("url", "http://localhost:9093")

    payload = [{
        "labels": {
            "alertname": f"SLOBurnRate_{alert.get('service', 'unknown')}",
            "service": alert.get("service", "unknown"),
            "severity": severity,
            "objective": alert.get("objective", "availability"),
            "window": alert.get("window", "unknown"),
        },
        "annotations": {
            "summary": f"SLO burn rate alert for {alert.get('service', 'unknown')}",
            "description": (
                f"Burn rate {alert.get('burn_rate', 0):.2f}x for "
                f"{alert.get('service', 'unknown')} ({alert.get('objective', 'availability')}) "
                f"over {alert.get('window', 'unknown')} window"
            ),
            "burn_rate": str(alert.get("burn_rate", 0)),
            "error_budget_remaining": str(alert.get("error_budget_remaining", "N/A")),
        },
        "generatorURL": am_config.get("generator_url", ""),
    }]

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{url}/api/v2/alerts",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status == 200
    except urllib.error.URLError as e:
        print(f"  [alertmanager] Failed: {e}", file=sys.stderr)
        return False


def send_slack(config, alert, severity):
    """Send alert to Slack via incoming webhook."""
    slack_config = config["channels"].get("slack", {})
    webhook_url = slack_config.get("webhook_url")
    if not webhook_url:
        print("  [slack] No webhook_url configured", file=sys.stderr)
        return False

    color_map = {"critical": "#FF0000", "warning": "#FFA500", "info": "#36A64F"}
    color = color_map.get(severity, "#808080")
    service = alert.get("service", "unknown")
    burn_rate = alert.get("burn_rate", 0)
    window = alert.get("window", "unknown")
    budget = alert.get("error_budget_remaining", "N/A")

    payload = {
        "attachments": [{
            "color": color,
            "title": f"SLO Alert: {service} [{severity.upper()}]",
            "fields": [
                {"title": "Service", "value": service, "short": True},
                {"title": "Severity", "value": severity.upper(), "short": True},
                {"title": "Burn Rate", "value": f"{burn_rate:.2f}x", "short": True},
                {"title": "Window", "value": window, "short": True},
                {"title": "Error Budget Remaining", "value": str(budget), "short": True},
                {"title": "Objective", "value": alert.get("objective", "availability"), "short": True},
            ],
            "ts": int(datetime.now(timezone.utc).timestamp()),
        }]
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status == 200
    except urllib.error.URLError as e:
        print(f"  [slack] Failed: {e}", file=sys.stderr)
        return False


def send_email(config, alert, severity):
    """Send alert via SMTP email."""
    email_config = config["channels"].get("email", {})
    smtp_host = email_config.get("smtp_host")
    smtp_port = email_config.get("smtp_port", 587)
    username = email_config.get("username", "")
    password = email_config.get("password", os.environ.get("ALERT_EMAIL_PASSWORD", ""))
    from_addr = email_config.get("from", username)
    to_addrs = email_config.get("to", [])

    if not smtp_host or not to_addrs:
        print("  [email] SMTP not configured or no recipients", file=sys.stderr)
        return False

    service = alert.get("service", "unknown")
    burn_rate = alert.get("burn_rate", 0)

    subject = f"[{severity.upper()}] SLO Alert: {service} burn rate {burn_rate:.2f}x"
    body = (
        f"SLO Burn Rate Alert\n"
        f"{'=' * 40}\n\n"
        f"Service:      {service}\n"
        f"Severity:     {severity.upper()}\n"
        f"Objective:    {alert.get('objective', 'availability')}\n"
        f"Burn Rate:    {burn_rate:.2f}x\n"
        f"Window:       {alert.get('window', 'unknown')}\n"
        f"Budget Left:  {alert.get('error_budget_remaining', 'N/A')}\n"
        f"Timestamp:    {datetime.now(timezone.utc).isoformat()}\n"
    )

    msg = MIMEMultipart()
    msg["From"] = from_addr
    msg["To"] = ", ".join(to_addrs)
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain"))

    try:
        with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as server:
            server.starttls()
            if username and password:
                server.login(username, password)
            server.sendmail(from_addr, to_addrs, msg.as_string())
        return True
    except Exception as e:
        print(f"  [email] Failed: {e}", file=sys.stderr)
        return False


CHANNEL_HANDLERS = {
    "alertmanager": send_alertmanager,
    "slack": send_slack,
    "email": send_email,
}


def route_alert(config, alert):
    """Route a single alert to the appropriate channels."""
    severity = alert.get("severity") or determine_severity(alert)
    channels = get_routes(config, severity)
    service = alert.get("service", "unknown")

    print(f"Routing alert: {service} [{severity}] -> {channels}")
    results = {}
    for channel in channels:
        handler = CHANNEL_HANDLERS.get(channel)
        if handler:
            ok = handler(config, alert, severity)
            results[channel] = "sent" if ok else "failed"
            print(f"  [{channel}] {'sent' if ok else 'FAILED'}")
        else:
            print(f"  [{channel}] Unknown channel, skipping")
            results[channel] = "unknown"
    return results


def main():
    parser = argparse.ArgumentParser(description="Multi-channel alert router")
    parser.add_argument("--config", required=True, help="Path to alert routing config JSON")
    parser.add_argument("--alert", help="Alert JSON string")
    parser.add_argument("--stdin", action="store_true", help="Read alerts from stdin (one JSON per line)")
    args = parser.parse_args()

    config = load_config(args.config)

    if args.alert:
        alert = json.loads(args.alert)
        route_alert(config, alert)
    elif args.stdin:
        for line in sys.stdin:
            line = line.strip()
            if line:
                alert = json.loads(line)
                route_alert(config, alert)
    else:
        parser.error("Provide --alert or --stdin")


if __name__ == "__main__":
    main()
