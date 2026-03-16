#!/bin/bash
# SentinelClaw Skill Scanner - Uses security database to check skills
# Usage: ./scan-skill.sh /path/to/skill [options]

# 动态检测 workspace 目录
if [ -n "$SENTINELCLAW_WORKSPACE" ]; then
    WORKSPACE_DIR="$SENTINELCLAW_WORKSPACE"
elif [ -d "$HOME/.openclaw/workspace" ]; then
    WORKSPACE_DIR="$HOME/.openclaw/workspace"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# 安全数据库路径
if [ -d "$WORKSPACE_DIR/security-db" ]; then
    SECURITY_DB="$WORKSPACE_DIR/security-db"
elif [ -d "$WORKSPACE_DIR/../security-db" ]; then
    SECURITY_DB="$WORKSPACE_DIR/../security-db"
else
    SECURITY_DB="$WORKSPACE_DIR/security-db"
fi

RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Risk scoring
RISK_SCORE=0
MAX_SCORE=100

usage() {
    echo "Usage: $0 /path/to/skill [options]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose    Show detailed findings"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 ../some-skill"
    echo "  $0 ../some-skill -v"
}

VERBOSE=false
SKILL_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [ -z "$SKILL_PATH" ]; then
                SKILL_PATH="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$SKILL_PATH" ]; then
    echo "Error: No skill path specified"
    usage
    exit 1
fi

if [ ! -d "$SKILL_PATH" ]; then
    echo "Error: Skill directory not found: $SKILL_PATH"
    exit 1
fi

SKILL_NAME=$(basename "$SKILL_PATH")

echo "═══════════════════════════════════════════════════════════"
echo "  Skill Security Scan: $SKILL_NAME"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Scanning source code for risk indicators..."
echo ""

# 风险指标字典
declare -A RISK_INDICATORS=(
    ["exec"]=15
    ["spawn"]=15
    ["eval"]=20
    ["curl"]=5
    ["wget"]=5
    ["fetch"]=5
    ["sudo"]=20
    ["chmod"]=10
    ["chown"]=15
    ["password"]=15
    ["token"]=15
    ["secret"]=15
    ["credential"]=15
    ["api_key"]=15
    ["~/.clawdbot/.env"]=25
    ["~/.ssh/id_rsa"]=25
    ["~/.bashrc"]=15
    ["base64"]=5
    ["decode"]=5
    ["import os"]=3
    ["subprocess"]=10
    ["system("]=10
    ["popen"]=10
)

FOUND_RISKS=()
SCANNED_FILES=0

# 扫描所有代码文件（不仅是 SKILL.md）
while IFS= read -r -d '' file; do
    SCANNED_FILES=$((SCANNED_FILES + 1))
    
    # 跳过二进制文件
    if file "$file" | grep -q "binary"; then
        continue
    fi
    
    # 扫描风险指标
    for indicator in "${!RISK_INDICATORS[@]}"; do
        if grep -qiE "$indicator" "$file" 2>/dev/null; then
            score=${RISK_INDICATORS[$indicator]}
            
            # 检查是否已在该文件中报告过此指标
            already_reported=false
            for reported in "${FOUND_RISKS[@]}"; do
                if [[ "$reported" == "$indicator in $(basename "$file")"* ]]; then
                    already_reported=true
                    break
                fi
            done
            
            if [ "$already_reported" = false ]; then
                RISK_SCORE=$((RISK_SCORE + score))
                FOUND_RISKS+=("$indicator in $(basename "$file"):$score")
                
                if $VERBOSE; then
                    echo -e "  ${YELLOW}⚠${NC} Found '$indicator' in $(basename "$file") (+$score risk)"
                fi
            fi
        fi
    done
done < <(find "$SKILL_PATH" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" -o -name "*.json" -o -name "*.md" -o -name "SKILL.md" \) -print0)

echo "Scanned $SCANNED_FILES files"
echo ""

# Check for IOCs

# Check for IOCs
echo ""
echo "Checking against threat intelligence database..."

# Check IPs
if [ -f "$SECURITY_DB/iocs/ips.txt" ]; then
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        IP=$(echo "$line" | awk '{print $1}')
        if grep -q "$IP" "$SKILL_MD" 2>/dev/null; then
            RISK_SCORE=$((RISK_SCORE + 50))
            FOUND_RISKS+=("IOC_IP:$IP:+50")
            echo -e "  ${RED}🚨${NC} BLACKLISTED IP FOUND: $IP (+50 risk)"
        fi
    done < "$SECURITY_DB/iocs/ips.txt"
fi

# Check domains
if [ -f "$SECURITY_DB/iocs/domains.txt" ]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        DOMAIN=$(echo "$line" | awk '{print $1}')
        # Handle wildcards
        if [[ "$DOMAIN" == *\** ]]; then
            PATTERN="${DOMAIN//\*/.*}"
            if grep -qE "$PATTERN" "$SKILL_MD" 2>/dev/null; then
                RISK_SCORE=$((RISK_SCORE + 50))
                FOUND_RISKS+=("IOC_DOMAIN:$DOMAIN:+50")
                echo -e "  ${RED}🚨${NC} BLACKLISTED DOMAIN PATTERN FOUND: $DOMAIN (+50 risk)"
            fi
        else
            if grep -q "$DOMAIN" "$SKILL_MD" 2>/dev/null; then
                RISK_SCORE=$((RISK_SCORE + 50))
                FOUND_RISKS+=("IOC_DOMAIN:$DOMAIN:+50")
                echo -e "  ${RED}🚨${NC} BLACKLISTED DOMAIN FOUND: $DOMAIN (+50 risk)"
            fi
        fi
    done < "$SECURITY_DB/iocs/domains.txt"
fi

# Cap risk score at MAX_SCORE
if [ $RISK_SCORE -gt $MAX_SCORE ]; then
    RISK_SCORE=$MAX_SCORE
fi

# Calculate normalized score (0-10 scale)
NORMALIZED_SCORE=$((RISK_SCORE / 10))

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Scan Results"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Determine risk level
if [ $NORMALIZED_SCORE -ge 8 ]; then
    RISK_LEVEL="${RED}CRITICAL${NC}"
    RECOMMENDATION="Installation BLOCKED - Critical security risks detected"
elif [ $NORMALIZED_SCORE -ge 5 ]; then
    RISK_LEVEL="${RED}HIGH${NC}"
    RECOMMENDATION="Manual review required before installation"
elif [ $NORMALIZED_SCORE -ge 3 ]; then
    RISK_LEVEL="${YELLOW}MEDIUM${NC}"
    RECOMMENDATION="Review findings, install with caution"
else
    RISK_LEVEL="${GREEN}LOW${NC}"
    RECOMMENDATION="Safe to install with standard monitoring"
fi

echo "Risk Score: $RISK_SCORE/$MAX_SCORE (normalized: $NORMALIZED_SCORE/10)"
echo "Risk Level: $RISK_LEVEL"
echo ""

if $VERBOSE && [ ${#FOUND_RISKS[@]} -gt 0 ]; then
    echo "Detailed findings:"
    for risk in "${FOUND_RISKS[@]}"; do
        echo "  - $risk"
    done
    echo ""
fi

echo "Recommendation: $RECOMMENDATION"
echo ""

# Exit codes: 0=safe, 1=medium/high risk, 2=critical risk
if [ $NORMALIZED_SCORE -ge 8 ]; then
    exit 2
elif [ $NORMALIZED_SCORE -ge 3 ]; then
    exit 1
else
    exit 0
fi
