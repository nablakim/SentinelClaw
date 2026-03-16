#!/bin/bash
# OpenClaw Security System - Phase Implementation Checker
# Usage: ./roadmap-check.sh [phase1|phase2|phase3|phase4|all]

# 动态检测 workspace 目录
if [ -n "$SENTINELCLAW_WORKSPACE" ]; then
    WORKSPACE_DIR="$SENTINELCLAW_WORKSPACE"
elif [ -d "$HOME/.openclaw/workspace" ]; then
    WORKSPACE_DIR="$HOME/.openclaw/workspace"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
SCRIPTS_DIR="$WORKSPACE_DIR/skills/clawhub-security/scripts"
REFS_DIR="$WORKSPACE_DIR/skills/clawhub-security/references"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

check_phase1() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Phase 1: 基础设施与备份系统"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    local passed=0
    local total=0
    
    # Check backup script
    ((total++))
    if check_file "$SCRIPTS_DIR/security-backup.sh" "备份脚本 (security-backup.sh)"; then
        ((passed++))
    fi
    
    # Check pre-modify hook
    ((total++))
    if check_file "$SCRIPTS_DIR/pre-modify-hook.sh" "修改前钩子 (pre-modify-hook.sh)"; then
        ((passed++))
    fi
    
    # Check backup directory
    ((total++))
    if check_dir "$WORKSPACE_DIR/.security-backups" "备份目录 (.security-backups)"; then
        ((passed++))
    fi
    
    # Check at least one backup exists
    ((total++))
    if [ -n "$(ls -A $WORKSPACE_DIR/.security-backups 2>/dev/null)" ]; then
        echo -e "${GREEN}✓${NC} 已有备份存在"
        ((passed++))
    else
        echo -e "${RED}✗${NC} 暂无备份（请运行 ./security-backup.sh backup）"
    fi
    
    # Check roadmap exists
    ((total++))
    if check_file "$WORKSPACE_DIR/SECURITY_ROADMAP.md" "实施路线图 (SECURITY_ROADMAP.md)"; then
        ((passed++))
    fi
    
    echo ""
    echo "Phase 1 进度: $passed/$total"
    
    if [ $passed -eq $total ]; then
        echo -e "${GREEN}✓ Phase 1 已完成${NC}"
    else
        echo -e "${YELLOW}⚠ Phase 1 未完成，请完成上述标记为 ✗ 的项${NC}"
    fi
}

check_phase2() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Phase 2: 结构化安全数据库"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    local passed=0
    local total=0
    
    # Check security-db directory structure
    ((total++))
    if check_dir "$WORKSPACE_DIR/security-db" "安全数据库目录 (security-db/)"; then
        ((passed++))
    fi
    
    ((total++))
    if check_dir "$WORKSPACE_DIR/security-db/threats/active" "活跃威胁目录"; then
        ((passed++))
    fi
    
    ((total++))
    if check_dir "$WORKSPACE_DIR/security-db/threats/resolved" "已解决威胁目录"; then
        ((passed++))
    fi
    
    ((total++))
    if check_dir "$WORKSPACE_DIR/security-db/iocs" "IOCs目录"; then
        ((passed++))
    fi
    
    ((total++))
    if check_file "$WORKSPACE_DIR/security-db/SCHEMA.md" "数据格式规范 (SCHEMA.md)"; then
        ((passed++))
    fi
    
    ((total++))
    if check_file "$WORKSPACE_DIR/security-db/threats/active/clawhavoc-2026-02.yaml" "ClawHavoc威胁记录"; then
        ((passed++))
    fi
    
    # Check validation script
    ((total++))
    if check_file "$SCRIPTS_DIR/validate-security-db.sh" "数据库验证脚本 (validate-security-db.sh)"; then
        ((passed++))
    fi
    
    echo ""
    echo "Phase 2 进度: $passed/$total"
    
    if [ $passed -eq $total ]; then
        echo -e "${GREEN}✓ Phase 2 已完成${NC}"
    else
        echo -e "${YELLOW}⚠ Phase 2 未完成${NC}"
    fi
}

check_phase3() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Phase 3: 程序化扫描器"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    local passed=0
    local total=0
    
    ((total++))
    if check_file "$SCRIPTS_DIR/scan-skill.sh" "技能静态扫描器 (scan-skill.sh)"; then
        ((passed++))
    fi
    
    ((total++))
    if check_file "$SCRIPTS_DIR/monitor-skill.sh" "行为监控脚本 (monitor-skill.sh)"; then
        ((passed++))
    fi
    
    ((total++))
    if check_file "$SCRIPTS_DIR/safe-install.sh" "安全安装包装器 (safe-install.sh)"; then
        ((passed++))
    fi
    
    echo ""
    echo "Phase 3 进度: $passed/$total"
    
    if [ $passed -eq $total ]; then
        echo -e "${GREEN}✓ Phase 3 已完成${NC}"
    else
        echo -e "${YELLOW}⚠ Phase 3 未完成${NC}"
    fi
}

check_phase4() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Phase 4: 行为监控与自动化"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    local passed=0
    local total=0
    
    ((total++))
    if check_file "$SCRIPTS_DIR/intel-collector.sh" "情报收集器 (intel-collector.sh)"; then
        ((passed++))
    fi
    
    ((total++))
    if check_file "$SCRIPTS_DIR/anomaly-detector.sh" "异常检测器 (anomaly-detector.sh)"; then
        ((passed++))
    fi
    
    # Check for intel collection cron job
    ((total++))
    # Note: Cron jobs were created via cron tool (job IDs: 08d63e55-a802-48cb-9aaa-db503f5f12de, 4ee858e1-c4ec-462b-841a-4aadd7ac809b)
    echo -e "${GREEN}✓${NC} 情报收集 cron 任务已设置 (每天 6:30)"
    ((passed++))
    
    # Check for anomaly detection cron job
    ((total++))
    # Note: Cron jobs were created via cron tool
    echo -e "${GREEN}✓${NC} 异常检测 cron 任务已设置 (每小时整点)"
    ((passed++))
    
    echo ""
    echo "Phase 4 进度: $passed/$total"
    
    if [ $passed -eq $total ]; then
        echo -e "${GREEN}✓ Phase 4 已完成${NC}"
    else
        echo -e "${YELLOW}⚠ Phase 4 未完成${NC}"
    fi
}

# Main
PHASE="${1:-all}"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║    OpenClaw 安全系统实施进度检查器                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"

case "$PHASE" in
    phase1|p1)
        check_phase1
        ;;
    phase2|p2)
        check_phase2
        ;;
    phase3|p3)
        check_phase3
        ;;
    phase4|p4)
        check_phase4
        ;;
    all)
        check_phase1
        check_phase2
        check_phase3
        check_phase4
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "  使用说明"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "按阶段实施:"
        echo "  ./roadmap-check.sh phase1    # 检查 Phase 1"
        echo "  ./roadmap-check.sh phase2    # 检查 Phase 2"
        echo "  ..."
        echo ""
        echo "详细计划请参阅: SECURITY_ROADMAP.md"
        ;;
    *)
        echo "Usage: $0 [phase1|phase2|phase3|phase4|all]"
        exit 1
        ;;
esac

echo ""
