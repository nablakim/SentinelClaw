#!/bin/bash
# SentinelClaw Security System Backup & Rollback Utility
# Usage: ./security-backup.sh [backup|restore|list|clean]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 动态检测 workspace 目录
if [ -n "$SENTINELCLAW_WORKSPACE" ]; then
    WORKSPACE_DIR="$SENTINELCLAW_WORKSPACE"
elif [ -d "$HOME/.openclaw/workspace" ]; then
    WORKSPACE_DIR="$HOME/.openclaw/workspace"
else
    WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
BACKUP_DIR="$WORKSPACE_DIR/.security-backups"
SECURITY_FILES=(
    "SECURITY_MEMORY.md"
    "skills/clawhub-security/SKILL.md"
    "skills/clawhub-security/references/security-checklist.md"
    "skills/clawhub-security/references/threat-intelligence.md"
    "skills/clawhub-security/scripts/security-audit.sh"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory
init_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi
}

# Generate timestamp
generate_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Create backup
create_backup() {
    init_backup_dir
    local timestamp=$(generate_timestamp)
    local backup_name="security_backup_$timestamp"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log_info "Creating backup: $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Copy each security file
    local copied_count=0
    for file in "${SECURITY_FILES[@]}"; do
        local src="$WORKSPACE_DIR/$file"
        if [ -f "$src" ]; then
            local dst_dir="$backup_path/$(dirname "$file")"
            mkdir -p "$dst_dir"
            cp "$src" "$dst_dir/"
            copied_count=$((copied_count + 1))
            log_info "  ✓ $file"
        else
            log_warn "  ✗ $file (not found)"
        fi
    done
    
    # Create metadata file
    cat > "$backup_path/BACKUP_METADATA.txt" << EOF
Backup Name: $backup_name
Created At: $(date)
Timestamp: $timestamp
Files Backed Up: $copied_count
Backup Source: $WORKSPACE_DIR
EOF

    # Keep only last 5 backups
    clean_old_backups
    
    log_success "Backup created: $backup_name ($copied_count files)"
    echo "$backup_name"
}

# List all backups
list_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warn "No backup directory found"
        return 1
    fi
    
    log_info "Available backups (newest first):"
    echo ""
    
    local count=0
    for backup in $(ls -1t "$BACKUP_DIR" 2>/dev/null | grep "^security_backup_"); do
        count=$((count + 1))
        local meta_file="$BACKUP_DIR/$backup/BACKUP_METADATA.txt"
        if [ -f "$meta_file" ]; then
            local created=$(grep "Created At:" "$meta_file" | cut -d: -f2- | xargs)
            local file_count=$(grep "Files Backed Up:" "$meta_file" | cut -d: -f2 | xargs)
            echo "  [$count] $backup"
            echo "      Created: $created"
            echo "      Files: $file_count"
        else
            echo "  [$count] $backup (metadata missing)"
        fi
        echo ""
    done
    
    if [ $count -eq 0 ]; then
        log_warn "No backups found"
    else
        log_info "Total backups: $count (keeping last 5)"
    fi
}

# Restore from backup
restore_backup() {
    local backup_name="$1"
    
    if [ -z "$backup_name" ]; then
        log_error "No backup name specified"
        echo "Usage: $0 restore <backup_name>"
        echo ""
        list_backups
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$backup_path" ]; then
        log_error "Backup not found: $backup_name"
        return 1
    fi
    
    log_warn "About to restore from: $backup_name"
    log_warn "Current files will be overwritten!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    # Create emergency backup before restore
    log_info "Creating emergency backup before restore..."
    local emergency_backup=$(create_backup)
    log_info "Emergency backup: $emergency_backup"
    
    # Restore files
    log_info "Restoring files..."
    local restored_count=0
    for file in "${SECURITY_FILES[@]}"; do
        local src="$backup_path/$file"
        local dst="$WORKSPACE_DIR/$file"
        if [ -f "$src" ]; then
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            restored_count=$((restored_count + 1))
            log_success "  ✓ Restored: $file"
        fi
    done
    
    log_success "Restore complete! $restored_count files restored from $backup_name"
    log_info "Emergency backup available: $emergency_backup"
}

# Clean old backups (keep only last 5)
clean_old_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        return 0
    fi
    
    local backups=($(ls -1t "$BACKUP_DIR" 2>/dev/null | grep "^security_backup_"))
    local total=${#backups[@]}
    
    if [ $total -gt 5 ]; then
        log_info "Cleaning old backups (keeping last 5 of $total)..."
        for ((i=5; i<total; i++)); do
            local old_backup="$BACKUP_DIR/${backups[$i]}"
            rm -rf "$old_backup"
            log_info "  ✗ Removed: ${backups[$i]}"
        done
    fi
}

# Clean all backups
clean_all_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warn "No backup directory found"
        return 1
    fi
    
    log_warn "About to delete ALL backups!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Clean cancelled"
        return 0
    fi
    
    rm -rf "$BACKUP_DIR"
    log_success "All backups removed"
}

# Show usage
usage() {
    echo "OpenClaw Security System Backup Utility"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  backup              Create a new backup of security files"
    echo "  restore <name>      Restore from a specific backup"
    echo "  list                List all available backups"
    echo "  clean               Remove old backups (keep last 5)"
    echo "  clean-all           Remove ALL backups (use with caution)"
    echo ""
    echo "Examples:"
    echo "  $0 backup                    # Create backup"
    echo "  $0 list                      # Show all backups"
    echo "  $0 restore security_backup_20260315_143022"
}

# Main
case "${1:-}" in
    backup)
        create_backup
        ;;
    restore)
        restore_backup "$2"
        ;;
    list)
        list_backups
        ;;
    clean)
        clean_old_backups
        log_success "Cleanup complete"
        ;;
    clean-all)
        clean_all_backups
        ;;
    *)
        usage
        ;;
esac
