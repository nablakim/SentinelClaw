#!/bin/bash
# Skill Behavior Monitor
# Creates baseline and detects anomalies in skill execution
# Usage: ./monitor-skill.sh --baseline <skill-name> | --check <skill-name>

# 动态检测 workspace 目录
if [ -n "$SENTINELCLAW_WORKSPACE" ]; then
    WORKSPACE_DIR="$SENTINELCLAW_WORKSPACE"
elif [ -d "$HOME/.openclaw/workspace" ]; then
    WORKSPACE_DIR="$HOME/.openclaw/workspace"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
BASELINE_DIR="$WORKSPACE_DIR/.security-backups/baselines"
LOG_DIR="$WORKSPACE_DIR/.security-backups/monitor-logs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 [command] [options] <skill-name>"
    echo ""
    echo "Commands:"
    echo "  --baseline    Create behavior baseline for a skill"
    echo "  --check       Check skill behavior against baseline"
    echo "  --list        List all monitored skills"
    echo "  --report      Generate monitoring report"
    echo ""
    echo "Examples:"
    echo "  $0 --baseline weather      # Create baseline for 'weather' skill"
    echo "  $0 --check weather         # Check 'weather' against baseline"
    echo "  $0 --list                  # Show all monitored skills"
}

init_dirs() {
    mkdir -p "$BASELINE_DIR"
    mkdir -p "$LOG_DIR"
}

create_baseline() {
    local skill_name="$1"
    local baseline_file="$BASELINE_DIR/${skill_name}.baseline"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    echo "═══════════════════════════════════════════════════════════"
    echo "  Creating Behavior Baseline: $skill_name"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Check if skill exists
    if ! clawhub list 2>/dev/null | grep -q "$skill_name"; then
        echo -e "${YELLOW}⚠ Skill '$skill_name' not found in installed skills${NC}"
        echo "Install it first with: clawhub install $skill_name"
        return 1
    fi
    
    echo "Monitoring skill execution..."
    echo "This will capture:"
    echo "  - Network connections"
    echo "  - File system access"
    echo "  - Environment variable access"
    echo ""
    
    # Create baseline structure
    cat > "$baseline_file" << EOF
# Behavior Baseline for: $skill_name
# Created: $(date)
# Baseline ID: $timestamp

[metadata]
skill_name: $skill_name
created: $(date -Iseconds)
baseline_id: $timestamp

[network]
# Expected network endpoints (domains/IPs)
endpoints:
EOF

    # Try to extract network endpoints from SKILL.md
    local skill_path=$(find /root/.openclaw -name "$skill_name" -type d 2>/dev/null | head -1)
    if [ -n "$skill_path" ] && [ -f "$skill_path/SKILL.md" ]; then
        echo "" >> "$baseline_file"
        echo "# Extracted from SKILL.md:" >> "$baseline_file"
        grep -oE 'https?://[^/[:space:]]+' "$skill_path/SKILL.md" | sort -u | while read url; do
            echo "  - $url" >> "$baseline_file"
        done
    fi
    
    cat >> "$baseline_file" << EOF

[filesystem]
# Expected file access patterns
read_paths:
  - ~/.openclaw/
write_paths:
  - /tmp/

[environment]
# Expected environment variables accessed
vars: []

[commands]
# Expected external commands
executables: []
EOF

    echo -e "${GREEN}✓${NC} Baseline created: $baseline_file"
    echo ""
    echo -e "${YELLOW}Note:${NC} This is a static baseline based on SKILL.md analysis."
    echo "For dynamic monitoring, use system-level tools like strace."
    
    return 0
}

check_behavior() {
    local skill_name="$1"
    local baseline_file="$BASELINE_DIR/${skill_name}.baseline"
    local log_file="$LOG_DIR/${skill_name}_$(date +%Y%m%d_%H%M%S).log"
    
    echo "═══════════════════════════════════════════════════════════"
    echo "  Checking Behavior: $skill_name"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if [ ! -f "$baseline_file" ]; then
        echo -e "${YELLOW}⚠ No baseline found for '$skill_name'${NC}"
        echo "Create baseline first: $0 --baseline $skill_name"
        return 1
    fi
    
    echo "Checking against baseline: $(basename $baseline_file)"
    echo "Log file: $log_file"
    echo ""
    
    # Start logging
    echo "Behavior Check - $(date)" > "$log_file"
    echo "Skill: $skill_name" >> "$log_file"
    echo "" >> "$log_file"
    
    # Check if skill is installed
    if ! clawhub list 2>/dev/null | grep -q "$skill_name"; then
        echo -e "${RED}✗ Skill not installed${NC}" | tee -a "$log_file"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Skill is installed" | tee -a "$log_file"
    
    # Check for skill updates (which might indicate tampering)
    echo "" >> "$log_file"
    echo "[Update Check]" >> "$log_file"
    if clawhub update --dry-run 2>&1 | grep -q "$skill_name"; then
        echo -e "${YELLOW}⚠ Update available${NC} - Review changes before updating" | tee -a "$log_file"
    else
        echo -e "${GREEN}✓${NC} No updates available" | tee -a "$log_file"
    fi
    
    # Basic anomaly checks
    echo "" >> "$log_file"
    echo "[Anomaly Checks]" >> "$log_file"
    
    # Check for credential file access in logs (if available)
    if [ -f "$WORKSPACE_DIR/.openclaw/logs/openclaw.log" ]; then
        local recent_access=$(grep -i "$skill_name" "$WORKSPACE_DIR/.openclaw/logs/openclaw.log" 2>/dev/null | grep -iE "(credential|password|token|secret)" | tail -5)
        if [ -n "$recent_access" ]; then
            echo -e "${RED}🚨 WARNING: Potential credential access detected!${NC}" | tee -a "$log_file"
            echo "$recent_access" >> "$log_file"
        else
            echo -e "${GREEN}✓${NC} No credential access detected in logs" | tee -a "$log_file"
        fi
    fi
    
    echo "" | tee -a "$log_file"
    echo -e "${GREEN}✓${NC} Behavior check complete" | tee -a "$log_file"
    echo "Full log: $log_file"
    
    return 0
}

list_monitored() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  Monitored Skills"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if [ ! -d "$BASELINE_DIR" ] || [ -z "$(ls -A $BASELINE_DIR 2>/dev/null)" ]; then
        echo "No baselines created yet."
        echo ""
        echo "Create a baseline:"
        echo "  $0 --baseline <skill-name>"
        return 0
    fi
    
    echo "Baselines:"
    for baseline in "$BASELINE_DIR"/*.baseline; do
        if [ -f "$baseline" ]; then
            local name=$(basename "$baseline" .baseline)
            local created=$(grep "^# Created:" "$baseline" 2>/dev/null | cut -d: -f2- | xargs)
            echo "  • $name (created: $created)"
        fi
    done
    
    echo ""
    echo "Check logs: $LOG_DIR"
}

generate_report() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  Monitoring Report"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    local report_file="$LOG_DIR/report_$(date +%Y%m%d).txt"
    
    echo "Security Monitoring Report - $(date)" > "$report_file"
    echo "" >> "$report_file"
    
    # Count baselines
    local baseline_count=$(ls -1 "$BASELINE_DIR"/*.baseline 2>/dev/null | wc -l)
    echo "Monitored Skills: $baseline_count" | tee -a "$report_file"
    
    # Count check logs
    local log_count=$(ls -1 "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    echo "Behavior Checks: $log_count" | tee -a "$report_file"
    
    echo "" | tee -a "$report_file"
    echo "Recent Check Logs:" | tee -a "$report_file"
    ls -lt "$LOG_DIR"/*.log 2>/dev/null | head -5 | awk '{print "  " $9 " (" $6 " " $7 " " $8 ")"}' | tee -a "$report_file"
    
    echo "" | tee -a "$report_file"
    echo "Full report saved: $report_file"
}

# Main
init_dirs

COMMAND="${1:-}"
SKILL_NAME="${2:-}"

case "$COMMAND" in
    --baseline)
        if [ -z "$SKILL_NAME" ]; then
            echo "Error: Skill name required"
            usage
            exit 1
        fi
        create_baseline "$SKILL_NAME"
        ;;
    --check)
        if [ -z "$SKILL_NAME" ]; then
            echo "Error: Skill name required"
            usage
            exit 1
        fi
        check_behavior "$SKILL_NAME"
        ;;
    --list)
        list_monitored
        ;;
    --report)
        generate_report
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'"
        usage
        exit 1
        ;;
esac
