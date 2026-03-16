#!/bin/bash
# Pre-modification backup hook
# Source this script before making changes to security files

# 动态检测 workspace 目录
if [ -n "$SENTINELCLAW_WORKSPACE" ]; then
    WORKSPACE_DIR="$SENTINELCLAW_WORKSPACE"
elif [ -d "$HOME/.openclaw/workspace" ]; then
    WORKSPACE_DIR="$HOME/.openclaw/workspace"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
BACKUP_SCRIPT="$WORKSPACE_DIR/skills/clawhub-security/scripts/security-backup.sh"

if [ -f "$BACKUP_SCRIPT" ]; then
    echo "📦 Auto-creating backup before modification..."
    $BACKUP_SCRIPT backup > /dev/null 2>&1
    echo "✓ Backup created"
else
    echo "⚠️  Backup script not found, proceeding without backup"
fi
