#!/bin/bash
# Anomaly Detection System for OpenClaw
# Monitors system behavior and detects security anomalies
# Usage: ./anomaly-detector.sh [--continuous] [--report]

# 动态检测 workspace 目录
if [ -n "$SENTINELCLAW_WORKSPACE" ]; then
    WORKSPACE_DIR="$SENTINELCLAW_WORKSPACE"
elif [ -d "$HOME/.openclaw/workspace" ]; then
    WORKSPACE_DIR="$HOME/.openclaw/workspace"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
SECURITY_DB="$WORKSPACE_DIR/security-db"
LOG_DIR="$WORKSPACE_DIR/.security-backups/anomaly-logs"
BASELINE_DIR="$WORKSPACE_DIR/.security-backups/baselines"
ALERT_DIR="$WORKSPACE_DIR/.security-backups/alerts"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONTINUOUS=false
GENERATE_REPORT=false
ANOMALIES_FOUND=0

usage() {
    echo "Anomaly Detection System"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --continuous    Run continuous monitoring (until interrupted)"
    echo "  --report        Generate anomaly report"
    echo "  -h, --help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0              # Single check"
    echo "  $0 --continuous # Continuous monitoring"
    echo "  $0 --report     # Generate report"
}

init() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$ALERT_DIR"
}

log_anomaly() {
    local level="$1"
    local category="$2"
    local message="$3"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_file="$LOG_DIR/anomalies-$(date +%Y%m%d).log"
    
    echo "[$timestamp] [$level] [$category] $message" >> "$log_file"
    
    case "$level" in
        CRITICAL)
            echo -e "${RED}🚨 CRITICAL${NC} [$category] $message"
            ((ANOMALIES_FOUND++))
            ;;
        HIGH)
            echo -e "${RED}⚠️  HIGH${NC} [$category] $message"
            ((ANOMALIES_FOUND++))
            ;;
        MEDIUM)
            echo -e "${YELLOW}⚠️  MEDIUM${NC} [$category] $message"
            ((ANOMALIES_FOUND++))
            ;;
        LOW)
            echo -e "${BLUE}ℹ${NC} [$category] $message"
            ;;
    esac
}

# Check for credential file access
check_credential_access() {
    local credential_files=(
        "$WORKSPACE_DIR/.openclaw/credentials"
        "$HOME/.clawdbot/.env"
        "$HOME/.ssh/id_rsa"
        "$HOME/.bashrc"
    )
    
    for file in "${credential_files[@]}"; do
        if [ -f "$file" ]; then
            # Check recent access (within last hour)
            local recent_access=$(find "$file" -mmin -60 2>/dev/null)
            if [ -n "$recent_access" ]; then
                # Check if this is expected (during normal operation)
                local access_time=$(stat -c %y "$file" 2>/dev/null)
                log_anomaly "MEDIUM" "CREDENTIAL_ACCESS" "Credential file accessed: $file at $access_time"
            fi
            
            # Check permissions
            local perms=$(stat -c %a "$file" 2>/dev/null)
            if [ -n "$perms" ]; then
                if [[ "$file" == *"credentials"* ]] && [ "$perms" != "700" ]; then
                    log_anomaly "HIGH" "PERMISSIONS" "Credential directory has unsafe permissions: $perms (expected 700)"
                fi
            fi
        fi
    done
}

# Check for network connections to suspicious IPs
check_network_connections() {
    if ! command -v ss >/dev/null 2>&1 && ! command -v netstat >/dev/null 2>&1; then
        return 0
    fi
    
    if [ -f "$SECURITY_DB/iocs/ips.txt" ]; then
        while IFS= read -r ip; do
            [[ "$ip" =~ ^#.*$ ]] && continue
            [[ -z "$ip" ]] && continue
            
            local ip_clean=$(echo "$ip" | awk '{print $1}')
            
            # Check active connections
            local connections=""
            if command -v ss >/dev/null 2>&1; then
                connections=$(ss -tn 2>/dev/null | grep "$ip_clean" || true)
            elif command -v netstat >/dev/null 2>&1; then
                connections=$(netstat -tn 2>/dev/null | grep "$ip_clean" || true)
            fi
            
            if [ -n "$connections" ]; then
                log_anomaly "CRITICAL" "SUSPICIOUS_CONNECTION" "Active connection to blacklisted IP: $ip_clean"
            fi
        done < "$SECURITY_DB/iocs/ips.txt"
    fi
}

# Check for new/unexpected skills
check_skill_changes() {
    local current_skills="$LOG_DIR/.current-skills.tmp"
    local previous_skills="$LOG_DIR/.previous-skills.tmp"
    
    # Get current skills
    clawhub list 2>/dev/null | sort > "$current_skills"
    
    if [ -f "$previous_skills" ]; then
        # Check for new skills
        local new_skills=$(comm -13 "$previous_skills" "$current_skills")
        if [ -n "$new_skills" ]; then
            while IFS= read -r skill; do
                [ -z "$skill" ] && continue
                log_anomaly "MEDIUM" "NEW_SKILL" "New skill installed: $skill"
            done <<< "$new_skills"
        fi
        
        # Check for removed skills
        local removed_skills=$(comm -23 "$previous_skills" "$current_skills")
        if [ -n "$removed_skills" ]; then
            while IFS= read -r skill; do
                [ -z "$skill" ] && continue
                log_anomaly "LOW" "REMOVED_SKILL" "Skill removed: $skill"
            done <<< "$removed_skills"
        fi
    fi
    
    # Save current as previous for next run
    cp "$current_skills" "$previous_skills"
    rm -f "$current_skills"
}

# Check log file for suspicious entries
check_logs() {
    local log_file="$WORKSPACE_DIR/.openclaw/logs/openclaw.log"
    
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    # Check for error patterns
    local recent_errors=$(tail -1000 "$log_file" 2>/dev/null | grep -iE "(error|fail|exception)" | tail -10)
    if [ -n "$recent_errors" ]; then
        local error_count=$(echo "$recent_errors" | wc -l)
        if [ $error_count -gt 5 ]; then
            log_anomaly "MEDIUM" "LOG_ERRORS" "High number of recent errors in log: $error_count"
        fi
    fi
    
    # Check for tool failures
    local tool_failures=$(tail -1000 "$log_file" 2>/dev/null | grep -i "tool failed" | tail -5)
    if [ -n "$tool_failures" ]; then
        log_anomaly "LOW" "TOOL_FAILURES" "Recent tool failures detected in logs"
    fi
}

# Check file system for unexpected changes
check_filesystem() {
    # Check for unexpected files in workspace
    local suspicious_patterns=(
        "*.sh"  # Shell scripts (potential malware)
        "*.py"  # Python scripts
        "*.js"  # JavaScript files
    )
    
    for pattern in "${suspicious_patterns[@]}"; do
        # Only check recent files (last 24 hours)
        local recent_files=$(find "$WORKSPACE_DIR" -name "$pattern" -mtime -1 2>/dev/null | grep -v ".security-backups" | head -5)
        if [ -n "$recent_files" ]; then
            local count=$(echo "$recent_files" | wc -l)
            if [ $count -gt 0 ]; then
                log_anomaly "LOW" "NEW_FILES" "New $pattern files detected in workspace (count: $count)"
            fi
        fi
    done
}

# Check security database integrity
check_database_integrity() {
    if [ -f "$WORKSPACE_DIR/skills/clawhub-security/scripts/validate-security-db.sh" ]; then
        local result=$($WORKSPACE_DIR/skills/clawhub-security/scripts/validate-security-db.sh 2>&1)
        if echo "$result" | grep -q "failed"; then
            log_anomaly "HIGH" "DB_INTEGRITY" "Security database validation failed"
        fi
    fi
}

# Run all checks
run_checks() {
    check_credential_access
    check_network_connections
    check_skill_changes
    check_logs
    check_filesystem
    check_database_integrity
}

# Generate anomaly report
generate_report() {
    local report_file="$LOG_DIR/report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Anomaly Detection Report
Generated: $(date)
========================================

SUMMARY
-------
Anomalies Detected: $ANOMALIES_FOUND
Check Time: $(date +%H:%M:%S)

RECENT ALERTS
-------------
EOF

    # Add recent anomalies from log
    if [ -f "$LOG_DIR/anomalies-$(date +%Y%m%d).log" ]; then
        tail -20 "$LOG_DIR/anomalies-$(date +%Y%m%d).log" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "RECOMMENDATIONS" >> "$report_file"
    echo "---------------" >> "$report_file"
    
    if [ $ANOMALIES_FOUND -gt 0 ]; then
        echo "⚠️  $ANOMALIES_FOUND anomalies detected" >> "$report_file"
        echo "   Review detailed logs in: $LOG_DIR" >> "$report_file"
        echo "   Check alerts in: $ALERT_DIR" >> "$report_file"
    else
        echo "✓ No anomalies detected" >> "$report_file"
        echo "  System appears normal" >> "$report_file"
    fi
    
    echo ""
    echo "Report saved: $report_file"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --continuous)
            CONTINUOUS=true
            shift
            ;;
        --report)
            GENERATE_REPORT=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Initialize
init

# Main execution
if [ "$GENERATE_REPORT" = true ]; then
    generate_report
    exit 0
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Anomaly Detection System"
if [ "$CONTINUOUS" = true ]; then
    echo "  Mode: Continuous (Ctrl+C to stop)"
fi
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ "$CONTINUOUS" = true ]; then
    echo "Starting continuous monitoring..."
    echo ""
    
    while true; do
        echo "--- Check at $(date) ---"
        run_checks
        
        if [ $ANOMALIES_FOUND -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}⚠ $ANOMALIES_FOUND anomalies detected${NC}"
            
            # Create alert file for significant anomalies
            if [ $ANOMALIES_FOUND -ge 3 ]; then
                local alert_file="$ALERT_DIR/ALERT-$(date +%Y%m%d-%H%M%S).txt"
                cat > "$alert_file" << EOF
🚨 MULTIPLE ANOMALIES DETECTED 🚨

Time: $(date)
Count: $ANOMALIES_FOUND anomalies

Review logs: $LOG_DIR
EOF
                echo -e "${RED}🚨 Alert created: $alert_file${NC}"
            fi
        fi
        
        echo ""
        echo "Waiting 60 seconds before next check..."
        echo ""
        sleep 60
        
        # Reset counter for next iteration
        ANOMALIES_FOUND=0
    done
else
    # Single check
    run_checks
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Check Complete"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if [ $ANOMALIES_FOUND -gt 0 ]; then
        echo -e "${YELLOW}⚠ Found $ANOMALIES_FOUND anomalies${NC}"
        echo "Review logs: $LOG_DIR"
        exit 1
    else
        echo -e "${GREEN}✓ No anomalies detected${NC}"
        exit 0
    fi
fi
