#!/bin/bash
#
# SentinelClaw 安装脚本
# 自动配置 SentinelClaw 防御体系
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.openclaw/sentinelclaw"
CRON_SCHEDULE_INTEL="30 6 * * *"
CRON_SCHEDULE_ANOMALY="0 * * * *"
CRON_SCHEDULE_AUDIT="17 6 * * 1"

echo "🛡️  SentinelClaw 安装程序"
echo "=========================="
echo ""

# 检查依赖
check_dependencies() {
    echo "📋 检查依赖..."
    
    if ! command -v openclaw &> /dev/null; then
        echo "⚠️  警告: 未检测到 OpenClaw"
        echo "   SentinelClaw 需要 OpenClaw 环境才能正常工作"
    fi
    
    if ! command -v cron &> /dev/null && ! command -v crontab &> /dev/null; then
        echo "⚠️  警告: 未检测到 cron"
        echo "   自动化任务需要 cron 支持"
    fi
    
    echo "✓ 依赖检查完成"
    echo ""
}

# 创建目录结构
setup_directories() {
    echo "📁 创建目录结构..."
    
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}/scripts"
    mkdir -p "${INSTALL_DIR}/security-db"
    mkdir -p "${INSTALL_DIR}/.security-backups"
    
    echo "✓ 目录结构创建完成"
    echo ""
}

# 复制脚本
copy_scripts() {
    echo "📦 安装脚本..."
    
    cp "${SCRIPT_DIR}/scripts/"*.sh "${INSTALL_DIR}/scripts/"
    chmod +x "${INSTALL_DIR}/scripts/"*.sh
    
    echo "✓ 脚本安装完成"
    echo ""
}

# 复制安全数据库
copy_security_db() {
    echo "🗄️  设置安全数据库..."
    
    if [ -d "${SCRIPT_DIR}/security-db" ]; then
        cp -r "${SCRIPT_DIR}/security-db""*" "${INSTALL_DIR}/security-db/" 2>/dev/null || true
    fi
    
    # 创建基础威胁情报文件
    touch "${INSTALL_DIR}/security-db/iocs/ips.txt"
    touch "${INSTALL_DIR}/security-db/iocs/domains.txt"
    touch "${INSTALL_DIR}/security-db/iocs/checksums.txt"
    
    echo "✓ 安全数据库设置完成"
    echo ""
}

# 配置 cron 任务
setup_cron() {
    echo "⏰ 配置自动化任务..."
    
    # 获取当前 crontab
    current_crontab=$(crontab -l 2>/dev/null || echo "")
    
    # 检查是否已存在 SentinelClaw 任务
    if echo "$current_crontab" | grep -q "SentinelClaw"; then
        echo "ℹ️  SentinelClaw cron 任务已存在，跳过配置"
        return
    fi
    
    # 添加新任务
    new_crontab="${current_crontab}
# SentinelClaw 自动化任务
${CRON_SCHEDULE_INTEL} cd ${INSTALL_DIR}/scripts && ./intel-collector.sh --update > ${INSTALL_DIR}/.security-backups/intel-collector.log 2>&1
${CRON_SCHEDULE_ANOMALY} cd ${INSTALL_DIR}/scripts && ./anomaly-detector.sh > ${INSTALL_DIR}/.security-backups/anomaly-detector.log 2>&1
${CRON_SCHEDULE_AUDIT} cd ${INSTALL_DIR}/scripts && ./security-audit.sh > ${INSTALL_DIR}/.security-backups/security-audit.log 2>&1
"
    
    echo "$new_crontab" | crontab -
    
    echo "✓ Cron 任务配置完成"
    echo "   - 情报收集: 每天 6:30"
    echo "   - 异常检测: 每小时整点"
    echo "   - 安全审计: 每周一 6:17"
    echo ""
}

# 创建配置文件
create_config() {
    echo "⚙️  创建配置文件..."
    
    cat > "${INSTALL_DIR}/sentinelclaw.conf" << EOF
# SentinelClaw 配置文件

# 安装目录
INSTALL_DIR="${INSTALL_DIR}"

# 备份保留数量
BACKUP_KEEP_COUNT=5

# 异常检测敏感度 (low/medium/high)
ANOMALY_SENSITIVITY=medium

# 情报源（逗号分隔）
INTEL_SOURCES="github,virustotal"

# 日志级别 (debug/info/warn/error)
LOG_LEVEL=info
EOF
    
    echo "✓ 配置文件创建完成"
    echo ""
}

# 运行初始检查
run_initial_checks() {
    echo "🔍 运行初始检查..."
    
    cd "${INSTALL_DIR}/scripts"
    
    # 验证脚本
    if [ -f "./roadmap-check.sh" ]; then
        echo "📊 系统状态检查:"
        ./roadmap-check.sh all 2>/dev/null || true
    fi
    
    echo "✓ 初始检查完成"
    echo ""
}

# 显示完成信息
show_completion() {
    echo ""
    echo "🎉 SentinelClaw 安装完成！"
    echo "==========================="
    echo ""
    echo "安装目录: ${INSTALL_DIR}"
    echo ""
    echo "可用命令:"
    echo "  ${INSTALL_DIR}/scripts/scan-skill.sh \u003cskill-path\u003e    # 扫描技能"
    echo "  ${INSTALL_DIR}/scripts/safe-install.sh \u003cskill-name\u003e   # 安全安装"
    echo "  ${INSTALL_DIR}/scripts/anomaly-detector.sh            # 手动运行检测"
    echo "  ${INSTALL_DIR}/scripts/intel-collector.sh --update    # 更新情报"
    echo ""
    echo "查看日志: tail -f ${INSTALL_DIR}/.security-backups/*.log"
    echo ""
    echo "SentinelClaw 现已激活，开始自动保护您的 OpenClaw 实例。"
    echo ""
}

# 主函数
main() {
    check_dependencies
    setup_directories
    copy_scripts
    copy_security_db
    setup_cron
    create_config
    run_initial_checks
    show_completion
}

main "$@"
