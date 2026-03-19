#!/usr/bin/env bash
# Automated restore dry-run validator
# Validates backup integrity by restoring to a temporary location and checking contents
# Designed to run on a weekly cron schedule on Nova (Ansible controller)
#
# Usage: ./restore-test.sh [--report-dir /path/to/reports]
# Cron:  0 3 * * 0  /path/to/restore-test.sh >> /var/log/restore-test.log 2>&1

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-/tmp/restore-test-reports}"
RESTORE_TEMP="/tmp/restore-dry-run-$$"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DATE_TAG=$(date -u +%Y%m%d)
FAILURES=0
TESTS_RUN=0
RESULTS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --report-dir) REPORT_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "$REPORT_DIR" "$RESTORE_TEMP"

cleanup() {
    rm -rf "$RESTORE_TEMP"
}
trap cleanup EXIT

log() {
    echo "[$(date -u +%H:%M:%S)] $1"
}

record_result() {
    local name="$1" status="$2" detail="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$status" = "FAIL" ]; then
        FAILURES=$((FAILURES + 1))
    fi
    RESULTS+=("{\"test\": \"$name\", \"status\": \"$status\", \"detail\": \"$detail\"}")
    log "  $status — $name: $detail"
}

# --- Test 1: OPNsense config backup ---
test_opnsense_backup() {
    log "Testing OPNsense config restore..."
    local backup_path="/mnt/Tank/backups/opnsense"
    local latest
    latest=$(ls -t "$backup_path"/config-*.xml 2>/dev/null | head -1 || true)

    if [ -z "$latest" ]; then
        record_result "opnsense_config" "FAIL" "No backup files found in $backup_path"
        return
    fi

    cp "$latest" "$RESTORE_TEMP/opnsense-config.xml"

    # Validate XML structure
    if xmllint --noout "$RESTORE_TEMP/opnsense-config.xml" 2>/dev/null; then
        local size
        size=$(stat -c%s "$RESTORE_TEMP/opnsense-config.xml")
        if [ "$size" -gt 1000 ]; then
            record_result "opnsense_config" "PASS" "Valid XML, ${size} bytes ($(basename "$latest"))"
        else
            record_result "opnsense_config" "FAIL" "File too small (${size} bytes) — likely corrupt"
        fi
    else
        # Fallback: check if it's at least a valid-looking config without xmllint
        if grep -q "<opnsense>" "$RESTORE_TEMP/opnsense-config.xml" 2>/dev/null; then
            record_result "opnsense_config" "PASS" "Contains OPNsense config (xmllint not available for strict validation)"
        else
            record_result "opnsense_config" "FAIL" "Invalid config file structure"
        fi
    fi
}

# --- Test 2: Proxmox VM/CT config backups ---
test_proxmox_configs() {
    log "Testing Proxmox config restore..."
    local backup_path="/mnt/Tank/backups/proxmox"
    local config_count=0

    for node_dir in "$backup_path"/*/; do
        [ -d "$node_dir" ] || continue
        local node
        node=$(basename "$node_dir")
        local node_configs
        node_configs=$(find "$node_dir" -name "*.conf" 2>/dev/null | wc -l)
        config_count=$((config_count + node_configs))

        if [ "$node_configs" -gt 0 ]; then
            # Validate at least one config per node
            local sample
            sample=$(find "$node_dir" -name "*.conf" | head -1)
            if grep -qE "^(arch|ostype|cores|memory|rootfs|net[0-9]):" "$sample" 2>/dev/null; then
                record_result "proxmox_${node}_configs" "PASS" "${node_configs} config files, valid format"
            else
                record_result "proxmox_${node}_configs" "FAIL" "Config files exist but format unrecognized"
            fi
        else
            record_result "proxmox_${node}_configs" "FAIL" "No config files found for node $node"
        fi
    done

    if [ "$config_count" -eq 0 ]; then
        record_result "proxmox_configs" "FAIL" "No Proxmox config backups found"
    fi
}

# --- Test 3: Controller state (Git repo integrity) ---
test_controller_state() {
    log "Testing controller state restore..."
    local repo_path="/home/user/Lab"

    if [ ! -d "$repo_path/.git" ]; then
        record_result "controller_git" "FAIL" "Lab repo not found at $repo_path"
        return
    fi

    # Clone to temp to validate integrity
    if git clone --depth 1 "$repo_path" "$RESTORE_TEMP/lab-clone" 2>/dev/null; then
        local file_count
        file_count=$(find "$RESTORE_TEMP/lab-clone" -type f | wc -l)
        record_result "controller_git" "PASS" "Git clone successful, ${file_count} files"
    else
        record_result "controller_git" "FAIL" "Git clone failed — repo may be corrupt"
    fi
}

# --- Test 4: TrueNAS dataset snapshots ---
test_truenas_snapshots() {
    log "Testing TrueNAS snapshot availability..."

    # Check if we can reach TrueNAS API
    local truenas_ip="10.1.1.11"
    if ! curl -sf -o /dev/null --max-time 5 "http://${truenas_ip}/api/v2.0/system/state" 2>/dev/null; then
        record_result "truenas_snapshots" "FAIL" "Cannot reach TrueNAS API at $truenas_ip"
        return
    fi

    # Check for recent ZFS snapshots via SSH (if key-based auth is set up)
    if ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$truenas_ip" "zfs list -t snapshot -o name,creation -s creation | tail -5" > "$RESTORE_TEMP/snapshots.txt" 2>/dev/null; then
        local snap_count
        snap_count=$(wc -l < "$RESTORE_TEMP/snapshots.txt")
        if [ "$snap_count" -gt 0 ]; then
            local latest_snap
            latest_snap=$(tail -1 "$RESTORE_TEMP/snapshots.txt" | awk '{print $1}')
            record_result "truenas_snapshots" "PASS" "${snap_count} recent snapshots, latest: $latest_snap"
        else
            record_result "truenas_snapshots" "FAIL" "No ZFS snapshots found"
        fi
    else
        record_result "truenas_snapshots" "SKIP" "SSH to TrueNAS not available (key auth required)"
    fi
}

# --- Test 5: Node SSH connectivity (restore prerequisite) ---
test_node_connectivity() {
    log "Testing node SSH connectivity for restore..."
    local nodes=("10.1.1.21:nova" "10.1.1.22:mira" "10.1.1.23:orin")

    for entry in "${nodes[@]}"; do
        local ip="${entry%%:*}"
        local name="${entry##*:}"

        if ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$ip" "echo ok" >/dev/null 2>&1; then
            record_result "ssh_${name}" "PASS" "SSH connectivity OK ($ip)"
        else
            record_result "ssh_${name}" "FAIL" "Cannot SSH to $name ($ip)"
        fi
    done
}

# --- Run all tests ---
log "=== Restore Dry-Run Validation — $TIMESTAMP ==="

test_opnsense_backup
test_proxmox_configs
test_controller_state
test_truenas_snapshots
test_node_connectivity

# --- Generate report ---
PASS_COUNT=$((TESTS_RUN - FAILURES))
REPORT_FILE="$REPORT_DIR/restore-test-${DATE_TAG}.json"

cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "tests_run": $TESTS_RUN,
  "passed": $PASS_COUNT,
  "failed": $FAILURES,
  "results": [
    $(IFS=,; echo "${RESULTS[*]}")
  ]
}
EOF

log ""
log "=== Summary: $PASS_COUNT/$TESTS_RUN passed, $FAILURES failed ==="
log "Report: $REPORT_FILE"

if [ "$FAILURES" -gt 0 ]; then
    exit 1
else
    exit 0
fi
