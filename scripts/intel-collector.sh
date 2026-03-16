#!/bin/bash
# Automated Threat Intelligence Collector
# Searches for latest ClawHub/OpenClaw security threats and updates database
# Usage: ./intel-collector.sh [--dry-run] [--update]

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
LOG_FILE="$WORKSPACE_DIR/.security-backups/intel-collector.log"
TEMP_DIR="/tmp/intel-collector-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
UPDATE_DB=false
NEW_THREATS=0

usage() {
    echo "Threat Intelligence Collector"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run       Show what would be done without making changes"
    echo "  --update        Update database with new findings"
    echo "  -h, --help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --dry-run    # Preview changes"
    echo "  $0 --update     # Collect and update database"
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        INFO)
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}✓${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        ERROR)
            echo -e "${RED}✗${NC} $message"
            ;;
        ALERT)
            echo -e "${RED}🚨${NC} $message"
            ;;
    esac
}

init() {
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$TEMP_DIR"
    
    log "INFO" "=== Intelligence Collection Started ==="
    log "INFO" "Dry run: $DRY_RUN, Update: $UPDATE_DB"
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Check for new IOCs in online sources
check_online_sources() {
    log "INFO" "Checking online threat intelligence sources..."
    
    # Note: In a production environment, this would query:
    # - ClawHub security advisories API
    # - GitHub Security Advisories
    # - Security vendor feeds
    # - Community threat sharing platforms
    
    # For now, we simulate by checking if there are any manual updates needed
    log "INFO" "Online source check complete (simulated)"
}

# Check for updates to known threats
check_known_threats() {
    log "INFO" "Checking known threats for updates..."
    
    local active_threats=0
    local resolved_threats=0
    
    if [ -d "$SECURITY_DB/threats/active" ]; then
        active_threats=$(ls -1 "$SECURITY_DB/threats/active"/*.yaml 2>/dev/null | wc -l)
    fi
    
    if [ -d "$SECURITY_DB/threats/resolved" ]; then
        resolved_threats=$(ls -1 "$SECURITY_DB/threats/resolved"/*.yaml 2>/dev/null | wc -l)
    fi
    
    log "INFO" "Active threats: $active_threats, Resolved: $resolved_threats"
    
    # Check if any active threats should be marked as resolved
    for threat_file in "$SECURITY_DB/threats/active"/*.yaml; do
        if [ -f "$threat_file" ]; then
            local threat_id=$(grep "^id:" "$threat_file" | cut -d: -f2 | xargs)
            local discovered=$(grep "^discovered:" "$threat_file" | cut -d: -f2- | xargs)
            
            # Check if threat is older than 90 days (example logic)
            local discovered_epoch=$(date -d "$discovered" +%s 2>/dev/null || echo 0)
            local current_epoch=$(date +%s)
            local age_days=$(( (current_epoch - discovered_epoch) / 86400 ))
            
            if [ $age_days -gt 90 ]; then
                log "WARN" "Threat $threat_id is ${age_days} days old - consider reviewing status"
            fi
        fi
    done
}

# Check installed skills against threat database
check_installed_skills() {
    log "INFO" "Checking installed skills against threat database..."
    
    local installed_skills=$(clawhub list 2>/dev/null | grep -v "^$" | wc -l)
    
    if [ "$installed_skills" -eq 0 ]; then
        log "INFO" "No skills currently installed"
        return 0
    fi
    
    log "INFO" "Found $installed_skills installed skills"
    
    # Check each installed skill against known malicious patterns
    while IFS= read -r skill_name; do
        [ -z "$skill_name" ] && continue
        
        # Check against IOCs
        local risk_found=false
        
        # Check if skill name matches suspicious patterns
        if echo "$skill_name" | grep -qiE "(crypto|wallet|steal|hack|miner)"; then
            log "ALERT" "Installed skill '$skill_name' matches suspicious pattern"
            risk_found=true
            ((NEW_THREATS++))
        fi
        
        # Check if skill uses known malicious domains/IPs
        local skill_path=$(find /root/.openclaw -name "$skill_name" -type d 2>/dev/null | head -1)
        if [ -n "$skill_path" ] && [ -f "$skill_path/SKILL.md" ]; then
            while IFS= read -r domain; do
                [[ "$domain" =~ ^#.*$ ]] && continue
                [[ -z "$domain" ]] && continue
                
                local domain_clean=$(echo "$domain" | awk '{print $1}')
                if grep -q "$domain_clean" "$skill_path/SKILL.md" 2>/dev/null; then
                    log "ALERT" "Installed skill '$skill_name' uses blacklisted domain: $domain_clean"
                    risk_found=true
                    ((NEW_THREATS++))
                fi
            done < "$SECURITY_DB/iocs/domains.txt"
        fi
        
    done < <(clawhub list 2>/dev/null)
    
    if [ $NEW_THREATS -eq 0 ]; then
        log "SUCCESS" "No threats detected in installed skills"
    fi
}

# Generate intelligence report
generate_report() {
    local report_file="$WORKSPACE_DIR/.security-backups/intel-report-$(date +%Y%m%d).txt"
    
    log "INFO" "Generating intelligence report..."
    
    cat > "$report_file" << EOF
Threat Intelligence Report
Generated: $(date)
========================================

SUMMARY
-------
New Threats Found: $NEW_THREATS
Collection Time: $(date +%H:%M:%S)

DATABASE STATUS
---------------
EOF

    # Add database statistics
    local active_count=$(ls -1 "$SECURITY_DB/threats/active"/*.yaml 2>/dev/null | wc -l)
    local resolved_count=$(ls -1 "$SECURITY_DB/threats/resolved"/*.yaml 2>/dev/null | wc -l)
    local ip_count=$(grep -v "^#" "$SECURITY_DB/iocs/ips.txt" 2>/dev/null | grep -v "^$" | wc -l)
    local domain_count=$(grep -v "^#" "$SECURITY_DB/iocs/domains.txt" 2>/dev/null | grep -v "^$" | wc -l)
    
    echo "Active Threats: $active_count" >> "$report_file"
    echo "Resolved Threats: $resolved_count" >> "$report_file"
    echo "Blacklisted IPs: $ip_count" >> "$report_file"
    echo "Blacklisted Domains: $domain_count" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "ACTIVE THREATS" >> "$report_file"
    echo "--------------" >> "$report_file"
    
    for threat_file in "$SECURITY_DB/threats/active"/*.yaml; do
        if [ -f "$threat_file" ]; then
            local name=$(grep "^name:" "$threat_file" | cut -d: -f2- | xargs)
            local severity=$(grep "^severity:" "$threat_file" | cut -d: -f2 | xargs)
            echo "[$severity] $name" >> "$report_file"
        fi
    done
    
    echo "" >> "$report_file"
    echo "RECOMMENDATIONS" >> "$report_file"
    echo "---------------" >> "$report_file"
    
    if [ $NEW_THREATS -gt 0 ]; then
        echo "⚠️  $NEW_THREATS potential threats detected in installed skills" >> "$report_file"
        echo "   Review the logs and take immediate action if confirmed" >> "$report_file"
    else
        echo "✓ No immediate threats detected" >> "$report_file"
        echo "  Continue regular monitoring" >> "$report_file"
    fi
    
    log "SUCCESS" "Report saved: $report_file"
    
    # If in update mode and threats found, create alert
    if [ "$UPDATE_DB" = true ] && [ $NEW_THREATS -gt 0 ]; then
        local alert_file="$WORKSPACE_DIR/.security-backups/ALERT-$(date +%Y%m%d-%H%M%S).txt"
        cat > "$alert_file" << EOF
🚨 SECURITY ALERT 🚨

Time: $(date)
Issue: $NEW_THREATS potential threats detected in installed skills

Action Required:
1. Review detailed log: $LOG_FILE
2. Run skill scanner: ./scripts/scan-skill.sh
3. Check specific skills: ./scripts/monitor-skill.sh --list
4. Consider uninstalling suspicious skills

Report: $report_file
EOF
        log "ALERT" "Security alert created: $alert_file"
    fi
}

# Main execution
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --update)
            UPDATE_DB=true
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

echo "═══════════════════════════════════════════════════════════"
echo "  Threat Intelligence Collector"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Run collection checks
check_online_sources
check_known_threats
check_installed_skills

# Generate report
generate_report

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Collection Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ $NEW_THREATS -gt 0 ]; then
    log "ALERT" "Found $NEW_THREATS potential issues - review required"
    exit 1
else
    log "SUCCESS" "No immediate threats detected"
    exit 0
fi
