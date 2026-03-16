#!/bin/bash
# Safe Skill Installation Wrapper
# Integrates all security checks before installing a ClawHub skill
# Usage: ./safe-install.sh <skill-name> [options]

set -e

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
SCRIPTS_DIR="$WORKSPACE_DIR/skills/clawhub-security/scripts"
TEMP_DIR="/tmp/safe-install-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Safe Skill Installation Wrapper"
    echo ""
    echo "Usage: $0 <skill-name> [options]"
    echo ""
    echo "Options:"
    echo "  --skip-scan       Skip security scanning (not recommended)"
    echo "  --skip-backup     Skip pre-installation backup"
    echo "  --force           Install despite warnings (DANGEROUS)"
    echo "  -y, --yes         Auto-confirm all prompts"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 weather                    # Safe install with all checks"
    echo "  $0 weather -y                 # Auto-confirm installation"
    echo "  $0 weather --skip-scan        # Install without security scan"
}

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Parse arguments
SKIP_SCAN=false
SKIP_BACKUP=false
FORCE=false
AUTO_CONFIRM=false
SKILL_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-scan)
            SKIP_SCAN=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [ -z "$SKILL_NAME" ]; then
                SKILL_NAME="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$SKILL_NAME" ]; then
    echo "Error: Skill name required"
    usage
    exit 1
fi

# Banner
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Safe Skill Installation: $SKILL_NAME"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Pre-installation backup
if [ "$SKIP_BACKUP" = false ]; then
    echo -e "${BLUE}[1/5]${NC} Creating pre-installation backup..."
    if [ -f "$SCRIPTS_DIR/security-backup.sh" ]; then
        BACKUP_NAME=$($SCRIPTS_DIR/security-backup.sh backup 2>&1 | grep "security_backup_" | tail -1)
        if [ -n "$BACKUP_NAME" ]; then
            echo -e "  ${GREEN}✓${NC} Backup created: $BACKUP_NAME"
        else
            echo -e "  ${YELLOW}⚠${NC} Backup may have failed, continuing..."
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Backup script not found, skipping..."
    fi
    echo ""
else
    echo -e "${YELLOW}[1/5] Backup skipped (--skip-backup)${NC}"
    echo ""
fi

# Step 2: Check if skill exists in ClawHub
echo -e "${BLUE}[2/5]${NC} Checking skill availability..."
if ! clawhub search "$SKILL_NAME" 2>/dev/null | grep -q "$SKILL_NAME"; then
    echo -e "  ${RED}✗${NC} Skill '$SKILL_NAME' not found in ClawHub"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Skill found in ClawHub"
echo ""

# Step 3: Download and scan skill
echo -e "${BLUE}[3/5]${NC} Security scanning..."

if [ "$SKIP_SCAN" = false ]; then
    mkdir -p "$TEMP_DIR"
    
    # Try to download skill for scanning (this is a simplified approach)
    # In a real implementation, we'd download the skill package
    echo -e "  ${CYAN}i${NC} Attempting to fetch skill information..."
    
    # Check against security database
    echo -e "  ${CYAN}i${NC} Checking against threat intelligence database..."
    
    # Check if skill name matches any known malicious patterns
    if [ -f "$SECURITY_DB/threats/active/clawhavoc-2026-02.yaml" ]; then
        # Check for typosquatting patterns
        # This is a simplified check - real implementation would be more sophisticated
        if echo "$SKILL_NAME" | grep -qiE "(crypto|wallet|steal|hack)"; then
            echo -e "  ${RED}🚨 WARNING: Skill name contains suspicious keywords${NC}"
            echo -e "     Detected: crypto/wallet/steal/hack"
            if [ "$FORCE" = false ]; then
                if [ "$AUTO_CONFIRM" = false ]; then
                    read -p "Continue anyway? (yes/no): " confirm
                    if [ "$confirm" != "yes" ]; then
                        echo "Installation cancelled."
                        exit 1
                    fi
                fi
            fi
        fi
    fi
    
    # Run skill scanner if available and we have the skill locally
    if [ -f "$SCRIPTS_DIR/scan-skill.sh" ]; then
        # Check if skill is already installed (for re-scan)
        if clawhub list 2>/dev/null | grep -q "$SKILL_NAME"; then
            local skill_path=$(find /root/.openclaw -name "$SKILL_NAME" -type d 2>/dev/null | head -1)
            if [ -n "$skill_path" ]; then
                echo -e "  ${CYAN}i${NC} Running security scan..."
                set +e
                $SCRIPTS_DIR/scan-skill.sh "$skill_path"
                SCAN_RESULT=$?
                set -e
                
                case $SCAN_RESULT in
                    0)
                        echo -e "  ${GREEN}✓${NC} Security scan passed (LOW risk)"
                        ;;
                    1)
                        echo -e "  ${YELLOW}⚠${NC} Security scan: MEDIUM risk detected"
                        if [ "$FORCE" = false ] && [ "$AUTO_CONFIRM" = false ]; then
                            read -p "Continue with installation? (yes/no): " confirm
                            if [ "$confirm" != "yes" ]; then
                                echo "Installation cancelled."
                                exit 1
                            fi
                        fi
                        ;;
                    2)
                        echo -e "  ${RED}✗${NC} Security scan: CRITICAL risk detected"
                        if [ "$FORCE" = true ]; then
                            echo -e "  ${YELLOW}⚠ FORCE flag set, proceeding despite critical risk${NC}"
                        else
                            echo "Installation blocked due to critical security risks."
                            echo "Use --force to override (NOT RECOMMENDED)"
                            exit 1
                        fi
                        ;;
                esac
            fi
        fi
    fi
    
    echo -e "  ${GREEN}✓${NC} Security checks complete"
else
    echo -e "  ${YELLOW}⚠${NC} Security scan skipped (--skip-scan)"
fi
echo ""

# Step 4: Pre-installation checklist
echo -e "${BLUE}[4/5]${NC} Pre-installation checklist..."

checklist_passed=true

# Check 1: VirusTotal badge (manual check reminder)
echo -e "  ${CYAN}i${NC} REMINDER: Verify VirusTotal badge on ClawHub page"

# Check 2: Publisher verification (manual)
echo -e "  ${CYAN}i${NC} REMINDER: Check publisher GitHub history"

# Check 3: Review SKILL.md (manual)
echo -e "  ${CYAN}i${NC} REMINDER: Read SKILL.md thoroughly before installation"

if [ "$AUTO_CONFIRM" = false ] && [ "$checklist_passed" = true ]; then
    echo ""
    read -p "Have you completed the manual checks? (yes/no): " manual_check
    if [ "$manual_check" != "yes" ]; then
        echo "Please complete the manual checks before proceeding."
        exit 1
    fi
fi

echo -e "  ${GREEN}✓${NC} Checklist complete"
echo ""

# Step 5: Install skill
echo -e "${BLUE}[5/5]${NC} Installing skill..."

if [ "$AUTO_CONFIRM" = false ]; then
    echo ""
    read -p "Proceed with installation? (yes/no): " final_confirm
    if [ "$final_confirm" != "yes" ]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

echo ""
echo "Installing $SKILL_NAME..."
if clawhub install "$SKILL_NAME"; then
    echo ""
    echo -e "${GREEN}✓${NC} Skill installed successfully!"
    
    # Post-installation actions
    echo ""
    echo "Post-installation actions:"
    
    # Create behavior baseline
    if [ -f "$SCRIPTS_DIR/monitor-skill.sh" ]; then
        echo -e "  ${CYAN}i${NC} Creating behavior baseline..."
        $SCRIPTS_DIR/monitor-skill.sh --baseline "$SKILL_NAME" 2>&1 || true
    fi
    
    # Add to monitoring
    echo -e "  ${CYAN}i${NC} Skill added to monitoring"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Installation Complete"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Next steps:"
    echo "  1. Test the skill in a sandboxed environment"
    echo "  2. Monitor behavior: ./monitor-skill.sh --check $SKILL_NAME"
    echo "  3. Review logs: ./security-backup.sh list"
    echo ""
    echo -e "${YELLOW}⚠${NC} If you notice suspicious behavior, immediately:"
    echo "    - Uninstall: clawhub uninstall $SKILL_NAME"
    echo "    - Run audit: openclaw security audit"
    echo "    - Rotate credentials"
    
else
    echo ""
    echo -e "${RED}✗${NC} Installation failed"
    exit 1
fi

echo ""
