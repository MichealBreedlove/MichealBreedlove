#!/usr/bin/env bash
# CIS Benchmark Scanner for Ubuntu 22.04/24.04 LTS
# Implements key checks from CIS Ubuntu Linux Benchmark v2.0
#
# Usage: ./cis-benchmark.sh [--json] [--output /path/to/report]
# Must be run as root.
#
# Covers: filesystem, services, network, access control, logging, permissions

set -euo pipefail

JSON_OUTPUT=false
OUTPUT_FILE=""
PASS=0
FAIL=0
WARN=0
RESULTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_OUTPUT=true; shift ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Usage: $0 [--json] [--output /path/to/report]"; exit 1 ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must be run as root" >&2
    exit 1
fi

record() {
    local id="$1" title="$2" status="$3" detail="$4"
    case "$status" in
        PASS) PASS=$((PASS + 1)) ;;
        FAIL) FAIL=$((FAIL + 1)) ;;
        WARN) WARN=$((WARN + 1)) ;;
    esac
    if [ "$JSON_OUTPUT" = true ]; then
        RESULTS+=("{\"id\":\"$id\",\"title\":\"$title\",\"status\":\"$status\",\"detail\":\"$detail\"}")
    else
        printf "  [%-4s] %-8s %s — %s\n" "$id" "$status" "$title" "$detail"
    fi
}

echo "=== CIS Benchmark Scan — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "Host: $(hostname) | OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo ""

# ============================================================
# 1. Filesystem Configuration
# ============================================================
echo "--- 1. Filesystem Configuration ---"

# 1.1 Ensure /tmp is a separate partition
if findmnt -n /tmp >/dev/null 2>&1; then
    record "1.1" "/tmp is separate partition" "PASS" "$(findmnt -n -o SOURCE /tmp)"
else
    record "1.1" "/tmp is separate partition" "WARN" "Not a separate mount (acceptable for VMs with small disks)"
fi

# 1.2 Ensure /tmp has noexec,nosuid,nodev
if findmnt -n /tmp >/dev/null 2>&1; then
    opts=$(findmnt -n -o OPTIONS /tmp)
    missing=""
    for opt in noexec nosuid nodev; do
        echo "$opts" | grep -q "$opt" || missing="$missing $opt"
    done
    if [ -z "$missing" ]; then
        record "1.2" "/tmp mount options" "PASS" "noexec,nosuid,nodev set"
    else
        record "1.2" "/tmp mount options" "WARN" "Missing:$missing"
    fi
else
    record "1.2" "/tmp mount options" "WARN" "Skipped — /tmp not separate"
fi

# 1.3 Ensure cramfs is disabled
if ! modprobe -n -v cramfs 2>&1 | grep -q "install /bin/true\|install /bin/false"; then
    if lsmod | grep -q cramfs; then
        record "1.3" "cramfs disabled" "FAIL" "Module loaded"
    else
        record "1.3" "cramfs disabled" "WARN" "Not blacklisted but not loaded"
    fi
else
    record "1.3" "cramfs disabled" "PASS" "Module blocked"
fi

# 1.4 Ensure USB storage is restricted
if modprobe -n -v usb-storage 2>&1 | grep -q "install /bin/true\|install /bin/false"; then
    record "1.4" "USB storage restricted" "PASS" "Module blocked"
elif lsmod | grep -q usb_storage; then
    record "1.4" "USB storage restricted" "FAIL" "Module loaded"
else
    record "1.4" "USB storage restricted" "WARN" "Not blacklisted but not loaded"
fi

# ============================================================
# 2. Services
# ============================================================
echo "--- 2. Services ---"

# 2.1 Ensure unnecessary services are not running
for svc in avahi-daemon cups isc-dhcp-server slapd nfs-server rpcbind bind9 vsftpd dovecot-imapd squid snmpd; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        record "2.1" "$svc not running" "FAIL" "Service is active"
    else
        record "2.1" "$svc not running" "PASS" "Not active"
    fi
done

# 2.2 Ensure time synchronization is configured
if systemctl is-active --quiet systemd-timesyncd 2>/dev/null || \
   systemctl is-active --quiet chrony 2>/dev/null || \
   systemctl is-active --quiet ntp 2>/dev/null; then
    record "2.2" "Time sync configured" "PASS" "NTP service active"
else
    record "2.2" "Time sync configured" "FAIL" "No NTP service running"
fi

# ============================================================
# 3. Network Configuration
# ============================================================
echo "--- 3. Network Configuration ---"

# 3.1 Ensure IP forwarding is disabled (unless acting as router)
ip_fwd=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
if [ "$ip_fwd" = "0" ]; then
    record "3.1" "IP forwarding disabled" "PASS" "net.ipv4.ip_forward=0"
else
    record "3.1" "IP forwarding disabled" "WARN" "Enabled (expected if node runs containers/VMs)"
fi

# 3.2 Ensure ICMP redirects are not accepted
icmp_redir=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null || echo "1")
if [ "$icmp_redir" = "0" ]; then
    record "3.2" "ICMP redirects disabled" "PASS" "accept_redirects=0"
else
    record "3.2" "ICMP redirects disabled" "FAIL" "accept_redirects=1"
fi

# 3.3 Ensure source-routed packets not accepted
src_route=$(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null || echo "1")
if [ "$src_route" = "0" ]; then
    record "3.3" "Source routing disabled" "PASS" "accept_source_route=0"
else
    record "3.3" "Source routing disabled" "FAIL" "accept_source_route=1"
fi

# 3.4 Ensure TCP SYN cookies enabled
syncookies=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo "0")
if [ "$syncookies" = "1" ]; then
    record "3.4" "TCP SYN cookies enabled" "PASS" "tcp_syncookies=1"
else
    record "3.4" "TCP SYN cookies enabled" "FAIL" "tcp_syncookies=0"
fi

# ============================================================
# 4. Access Control
# ============================================================
echo "--- 4. Access & Authentication ---"

# 4.1 Ensure SSH root login is disabled
if sshd -T 2>/dev/null | grep -qi "^permitrootlogin no"; then
    record "4.1" "SSH root login disabled" "PASS" "PermitRootLogin no"
elif grep -qiE "^\s*PermitRootLogin\s+no" /etc/ssh/sshd_config 2>/dev/null; then
    record "4.1" "SSH root login disabled" "PASS" "PermitRootLogin no (config)"
else
    record "4.1" "SSH root login disabled" "WARN" "Root login may be permitted"
fi

# 4.2 Ensure SSH password authentication is disabled
if sshd -T 2>/dev/null | grep -qi "^passwordauthentication no"; then
    record "4.2" "SSH password auth disabled" "PASS" "Key-only auth"
elif grep -qiE "^\s*PasswordAuthentication\s+no" /etc/ssh/sshd_config 2>/dev/null; then
    record "4.2" "SSH password auth disabled" "PASS" "Key-only auth (config)"
else
    record "4.2" "SSH password auth disabled" "FAIL" "Password auth may be enabled"
fi

# 4.3 Ensure SSH protocol is 2
if sshd -T 2>/dev/null | grep -qi "^protocol 1"; then
    record "4.3" "SSH protocol 2" "FAIL" "Protocol 1 enabled"
else
    record "4.3" "SSH protocol 2" "PASS" "Protocol 2 (default on modern OpenSSH)"
fi

# 4.4 Ensure no empty passwords
if awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | grep -q .; then
    record "4.4" "No empty passwords" "FAIL" "Accounts with empty passwords found"
else
    record "4.4" "No empty passwords" "PASS" "No empty passwords"
fi

# 4.5 Ensure root is the only UID 0 account
uid0_count=$(awk -F: '($3 == 0) {print $1}' /etc/passwd | wc -l)
if [ "$uid0_count" -eq 1 ]; then
    record "4.5" "Single UID 0 account" "PASS" "Only root has UID 0"
else
    record "4.5" "Single UID 0 account" "FAIL" "$uid0_count accounts with UID 0"
fi

# ============================================================
# 5. Logging & Auditing
# ============================================================
echo "--- 5. Logging & Auditing ---"

# 5.1 Ensure rsyslog or journald is running
if systemctl is-active --quiet rsyslog 2>/dev/null || \
   systemctl is-active --quiet systemd-journald 2>/dev/null; then
    record "5.1" "System logging active" "PASS" "Logging service running"
else
    record "5.1" "System logging active" "FAIL" "No logging service detected"
fi

# 5.2 Ensure auditd is installed and running
if command -v auditd >/dev/null 2>&1 && systemctl is-active --quiet auditd 2>/dev/null; then
    record "5.2" "auditd running" "PASS" "Audit daemon active"
elif dpkg -s auditd >/dev/null 2>&1; then
    record "5.2" "auditd running" "WARN" "Installed but not running"
else
    record "5.2" "auditd running" "WARN" "Not installed (recommended for production)"
fi

# 5.3 Ensure log file permissions are restrictive
insecure_logs=$(find /var/log -type f -perm /037 2>/dev/null | head -5)
if [ -z "$insecure_logs" ]; then
    record "5.3" "Log file permissions" "PASS" "No world-readable/writable logs"
else
    record "5.3" "Log file permissions" "WARN" "Some logs have broad permissions"
fi

# ============================================================
# 6. File Permissions
# ============================================================
echo "--- 6. File Permissions ---"

# 6.1 Ensure /etc/passwd permissions
passwd_perm=$(stat -c %a /etc/passwd)
if [ "$passwd_perm" = "644" ]; then
    record "6.1" "/etc/passwd permissions" "PASS" "644"
else
    record "6.1" "/etc/passwd permissions" "FAIL" "$passwd_perm (expected 644)"
fi

# 6.2 Ensure /etc/shadow permissions
shadow_perm=$(stat -c %a /etc/shadow)
if [ "$shadow_perm" = "640" ] || [ "$shadow_perm" = "600" ] || [ "$shadow_perm" = "000" ]; then
    record "6.2" "/etc/shadow permissions" "PASS" "$shadow_perm"
else
    record "6.2" "/etc/shadow permissions" "FAIL" "$shadow_perm (expected 640 or stricter)"
fi

# 6.3 Ensure no world-writable files in system dirs
ww_files=$(find /usr /etc /bin /sbin -xdev -type f -perm -0002 2>/dev/null | head -5)
if [ -z "$ww_files" ]; then
    record "6.3" "No world-writable system files" "PASS" "Clean"
else
    record "6.3" "No world-writable system files" "FAIL" "World-writable files found"
fi

# 6.4 Ensure no unowned files
unowned=$(find / -xdev -nouser -o -nogroup 2>/dev/null | head -5)
if [ -z "$unowned" ]; then
    record "6.4" "No unowned files" "PASS" "All files have valid owners"
else
    record "6.4" "No unowned files" "WARN" "Some files have no valid owner"
fi

# ============================================================
# Summary
# ============================================================
TOTAL=$((PASS + FAIL + WARN))
echo ""
echo "=== Summary ==="
echo "  Total checks: $TOTAL"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  WARN: $WARN"

if [ "$JSON_OUTPUT" = true ] || [ -n "$OUTPUT_FILE" ]; then
    REPORT=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "os": "$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')",
  "summary": {"total": $TOTAL, "pass": $PASS, "fail": $FAIL, "warn": $WARN},
  "checks": [$(IFS=,; echo "${RESULTS[*]}")]
}
EOF
)
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$REPORT" > "$OUTPUT_FILE"
        echo "  Report: $OUTPUT_FILE"
    else
        echo "$REPORT"
    fi
fi

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
