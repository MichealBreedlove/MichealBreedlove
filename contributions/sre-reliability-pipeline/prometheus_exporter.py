#!/usr/bin/env python3
"""Prometheus metrics exporter for SLO evaluation results.

Exposes SLO compliance ratios, burn rates, error budgets, and incident
counts as Prometheus metrics on an HTTP endpoint for Grafana scraping.

Usage:
    python prometheus_exporter.py --port 9101 --slo-state /path/to/slo/state
    python prometheus_exporter.py --port 9101 --slo-catalog config/slo_catalog.json

Metrics exposed:
    slo_compliance_ratio        - Current SLO compliance (0.0-1.0)
    slo_target                  - SLO target threshold
    slo_burn_rate               - Burn rate per time window
    slo_error_budget_remaining  - Error budget remaining (0.0-1.0)
    slo_active_incidents        - Number of active incidents
    slo_safety_gate_blocked     - Whether safety gate is blocking (0/1)
    slo_mean_time_to_resolve_minutes - Mean TTR in minutes
    slo_evaluation_timestamp    - Last evaluation Unix timestamp
"""

import argparse
import json
import os
import sys
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path


class SLOMetricsCollector:
    """Reads SLO state files and produces Prometheus-format metrics."""

    def __init__(self, slo_state_dir, slo_catalog_path=None):
        self.slo_state_dir = Path(slo_state_dir)
        self.slo_catalog_path = Path(slo_catalog_path) if slo_catalog_path else None

    def _read_json(self, path):
        try:
            with open(path) as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return None

    def _find_latest_report(self):
        """Find the most recent SLO evaluation report."""
        reports_dir = self.slo_state_dir / "reports" / "daily"
        if not reports_dir.exists():
            reports_dir = self.slo_state_dir
        report_files = sorted(reports_dir.glob("*.json"), reverse=True)
        if report_files:
            return self._read_json(report_files[0])
        return None

    def _load_catalog(self):
        """Load SLO catalog for target values."""
        if self.slo_catalog_path and self.slo_catalog_path.exists():
            data = self._read_json(self.slo_catalog_path)
            if data and "slos" in data:
                return {s["service"]: s for s in data["slos"]}
        return {}

    def collect(self):
        """Collect all metrics and return as Prometheus text format."""
        lines = []
        catalog = self._load_catalog()
        report = self._find_latest_report()

        # SLO compliance and targets from catalog
        lines.append("# HELP slo_compliance_ratio Current SLO compliance ratio (0.0-1.0)")
        lines.append("# TYPE slo_compliance_ratio gauge")
        lines.append("# HELP slo_target SLO target threshold")
        lines.append("# TYPE slo_target gauge")

        if report and "slos" in report:
            for slo in report["slos"]:
                service = slo.get("service", "unknown")
                objective = slo.get("objective", "availability")
                compliance = slo.get("compliance", 0.0)
                labels = f'service="{service}",objective="{objective}"'
                lines.append(f"slo_compliance_ratio{{{labels}}} {compliance}")

                # Add per-window compliance if available
                for window, value in slo.get("windows", {}).items():
                    wlabels = f'service="{service}",objective="{objective}",window="{window}"'
                    lines.append(f"slo_compliance_ratio{{{wlabels}}} {value}")
        elif catalog:
            # Fallback: export targets from catalog even without report data
            for service, slo in catalog.items():
                target = slo.get("target", 0.0)
                objective = slo.get("objective", "availability")
                labels = f'service="{service}",objective="{objective}"'
                lines.append(f"slo_target{{{labels}}} {target}")

        # Burn rates
        lines.append("# HELP slo_burn_rate Error budget burn rate per time window")
        lines.append("# TYPE slo_burn_rate gauge")

        if report and "burn_rates" in report:
            for entry in report["burn_rates"]:
                service = entry.get("service", "unknown")
                for window, rate in entry.get("windows", {}).items():
                    labels = f'service="{service}",window="{window}"'
                    lines.append(f"slo_burn_rate{{{labels}}} {rate}")

        # Error budget remaining
        lines.append("# HELP slo_error_budget_remaining_ratio Error budget remaining (0.0-1.0)")
        lines.append("# TYPE slo_error_budget_remaining_ratio gauge")

        if report and "budgets" in report:
            for entry in report["budgets"]:
                service = entry.get("service", "unknown")
                remaining = entry.get("remaining_ratio", 1.0)
                lines.append(f'slo_error_budget_remaining_ratio{{service="{service}"}} {remaining}')

        # Active incidents
        lines.append("# HELP slo_active_incidents Number of active incidents")
        lines.append("# TYPE slo_active_incidents gauge")
        incident_count = 0
        if report:
            incident_count = report.get("active_incidents", 0)
        lines.append(f"slo_active_incidents {incident_count}")

        # Safety gate
        lines.append("# HELP slo_safety_gate_blocked Whether safety gate is blocking automation (0=clear, 1=blocked)")
        lines.append("# TYPE slo_safety_gate_blocked gauge")
        blocked = 0
        if report:
            blocked = 1 if report.get("safety_gate_blocked", False) else 0
        lines.append(f"slo_safety_gate_blocked {blocked}")

        # Mean time to resolve
        lines.append("# HELP slo_mean_time_to_resolve_minutes Mean time to resolve incidents in minutes")
        lines.append("# TYPE slo_mean_time_to_resolve_minutes gauge")
        mttr = report.get("mean_ttr_minutes", 0) if report else 0
        lines.append(f"slo_mean_time_to_resolve_minutes {mttr}")

        # Evaluation timestamp
        lines.append("# HELP slo_evaluation_timestamp Unix timestamp of last SLO evaluation")
        lines.append("# TYPE slo_evaluation_timestamp gauge")
        ts = report.get("timestamp_unix", time.time()) if report else time.time()
        lines.append(f"slo_evaluation_timestamp {ts}")

        return "\n".join(lines) + "\n"


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler that serves Prometheus metrics."""

    collector = None

    def do_GET(self):
        if self.path == "/metrics":
            output = self.collector.collect()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.end_headers()
            self.wfile.write(output.encode("utf-8"))
        elif self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok\n")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress request logging for cleaner output
        pass


def main():
    parser = argparse.ArgumentParser(description="Prometheus exporter for SLO metrics")
    parser.add_argument("--port", type=int, default=9101, help="Port to listen on (default: 9101)")
    parser.add_argument("--slo-state", default="artifacts/slo/state",
                        help="Directory containing SLO state/report files")
    parser.add_argument("--slo-catalog", default=None,
                        help="Path to SLO catalog JSON for target values")
    args = parser.parse_args()

    collector = SLOMetricsCollector(args.slo_state, args.slo_catalog)
    MetricsHandler.collector = collector

    server = HTTPServer(("0.0.0.0", args.port), MetricsHandler)
    print(f"SLO metrics exporter listening on :{args.port}/metrics")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down")
        server.server_close()


if __name__ == "__main__":
    main()
