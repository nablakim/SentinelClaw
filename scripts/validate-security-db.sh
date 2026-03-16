#!/bin/bash
# Security Database Validation Script
# Validates YAML syntax and required fields

# 动态检测 workspace 目录
if [ -n "$SENTINELCLAW_WORKSPACE" ]; then
    WORKSPACE_DIR="$SENTINELCLAW_WORKSPACE"
elif [ -d "$HOME/.openclaw/workspace" ]; then
    WORKSPACE_DIR="$HOME/.openclaw/workspace"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
DB_DIR="$WORKSPACE_DIR/security-db"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo "═══════════════════════════════════════════════════════════"
echo "  Security Database Validator"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if yq is available for YAML validation
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}⚠ yq not installed, using basic syntax checks${NC}"
    USE_YQ=false
else
    USE_YQ=true
fi

validate_yaml() {
    local file="$1"
    local basename=$(basename "$file")
    
    if $USE_YQ; then
        if yq eval '.' "$file" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $basename - Valid YAML"
            return 0
        else
            echo -e "${RED}✗${NC} $basename - Invalid YAML syntax"
            ((ERRORS++))
            return 1
        fi
    else
        # Basic check: file exists and is readable
        if [ -r "$file" ]; then
            echo -e "${GREEN}✓${NC} $basename - Readable"
            return 0
        else
            echo -e "${RED}✗${NC} $basename - Not readable"
            ((ERRORS++))
            return 1
        fi
    fi
}

check_required_field() {
    local file="$1"
    local field="$2"
    local basename=$(basename "$file")
    
    if $USE_YQ; then
        if yq eval ".$field" "$file" 2>/dev/null | grep -qv "^null$"; then
            return 0
        else
            echo -e "${RED}✗${NC} $basename - Missing required field: $field"
            ((ERRORS++))
            return 1
        fi
    else
        if grep -q "^$field:" "$file" 2>/dev/null; then
            return 0
        else
            echo -e "${YELLOW}⚠${NC} $basename - May be missing field: $field"
            ((WARNINGS++))
            return 1
        fi
    fi
}

# Check directory structure
echo "Checking directory structure..."
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2 - Missing"
        ((ERRORS++))
    fi
}

check_dir "$DB_DIR" "Database root"
check_dir "$DB_DIR/threats/active" "Active threats directory"
check_dir "$DB_DIR/threats/resolved" "Resolved threats directory"
check_dir "$DB_DIR/iocs" "IOCs directory"
check_dir "$DB_DIR/advisories" "Advisories directory"

echo ""

# Validate threat records
echo "Validating threat records..."
if [ -d "$DB_DIR/threats/active" ]; then
    for file in "$DB_DIR/threats/active"/*.yaml; do
        if [ -f "$file" ]; then
            validate_yaml "$file"
            if [ $? -eq 0 ]; then
                check_required_field "$file" "id"
                check_required_field "$file" "name"
                check_required_field "$file" "discovered"
                check_required_field "$file" "status"
                check_required_field "$file" "severity"
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠ No active threat records found${NC}"
fi

echo ""

# Check IOC files
echo "Checking IOC files..."

if [ -f "$DB_DIR/iocs/ips.txt" ]; then
    IP_COUNT=$(grep -v "^#" "$DB_DIR/iocs/ips.txt" | grep -v "^$" | wc -l)
    echo -e "${GREEN}✓${NC} IPs file - $IP_COUNT entries"
else
    echo -e "${YELLOW}⚠ IPs file not found${NC}"
fi

if [ -f "$DB_DIR/iocs/domains.txt" ]; then
    DOMAIN_COUNT=$(grep -v "^#" "$DB_DIR/iocs/domains.txt" | grep -v "^$" | wc -l)
    echo -e "${GREEN}✓${NC} Domains file - $DOMAIN_COUNT entries"
else
    echo -e "${YELLOW}⚠ Domains file not found${NC}"
fi

if [ -f "$DB_DIR/iocs/checksums.txt" ]; then
    HASH_COUNT=$(grep -v "^#" "$DB_DIR/iocs/checksums.txt" | grep -v "^$" | wc -l)
    echo -e "${GREEN}✓${NC} Checksums file - $HASH_COUNT entries"
else
    echo -e "${YELLOW}⚠ Checksums file not found${NC}"
fi

echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "  Validation Summary"
echo "═══════════════════════════════════════════════════════════"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with $WARNINGS warnings${NC}"
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS errors and $WARNINGS warnings${NC}"
    exit 1
fi
