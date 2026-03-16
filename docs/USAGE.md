# 使用手册

## 安全安装技能

### 推荐方式：safe-install.sh

```bash
~/.openclaw/sentinelclaw/scripts/safe-install.sh weather
```

这个命令会：
1. 下载技能
2. 执行静态扫描
3. 创建行为基线
4. 安装技能
5. 验证安装

### 手动扫描

```bash
# 基本扫描
~/.openclaw/sentinelclaw/scripts/scan-skill.sh /path/to/skill

# 详细扫描
~/.openclaw/sentinelclaw/scripts/scan-skill.sh /path/to/skill -v
```

## 监控与检测

### 查看异常检测报告

```bash
# 查看最新报告
cat ~/.openclaw/workspace/.security-backups/anomaly-logs/latest.log

# 查看所有异常告警
ls ~/.openclaw/workspace/.security-backups/alerts/
```

### 手动运行检测

```bash
# 运行异常检测
~/.openclaw/sentinelclaw/scripts/anomaly-detector.sh

# 生成报告
~/.openclaw/sentinelclaw/scripts/anomaly-detector.sh --report

# 更新威胁情报
~/.openclaw/sentinelclaw/scripts/intel-collector.sh --update
```

## 备份与恢复

### 创建备份

```bash
~/.openclaw/sentinelclaw/scripts/security-backup.sh backup
```

### 列出备份

```bash
~/.openclaw/sentinelclaw/scripts/security-backup.sh list
```

### 恢复备份

```bash
~/.openclaw/sentinelclaw/scripts/security-backup.sh restore security_backup_YYYYMMDD_HHMMSS
```

## 行为监控

### 创建技能基线

```bash
~/.openclaw/sentinelclaw/scripts/monitor-skill.sh --baseline skill-name
```

### 检查技能行为

```bash
~/.openclaw/sentinelclaw/scripts/monitor-skill.sh --check skill-name
```

### 生成监控报告

```bash
~/.openclaw/sentinelclaw/scripts/monitor-skill.sh --report
```

## 安全数据库

### 验证数据库

```bash
~/.openclaw/sentinelclaw/scripts/validate-security-db.sh
```

### 添加自定义威胁情报

编辑以下文件：
- `~/.openclaw/workspace/security-db/iocs/ips.txt`
- `~/.openclaw/workspace/security-db/iocs/domains.txt`
- `~/.openclaw/workspace/security-db/iocs/checksums.txt`

## 查看系统状态

```bash
~/.openclaw/sentinelclaw/scripts/roadmap-check.sh all
```

## 故障排除

### 检查日志

```bash
# 查看安装日志
tail -f ~/.openclaw/sentinelclaw/.security-backups/*.log

# 查看异常检测历史
ls -la ~/.openclaw/workspace/.security-backups/anomaly-logs/
```

### 常见问题

**Q: Cron 任务没有运行？**  
A: 检查 cron 服务状态：`systemctl status cron` 或 `service cron status`

**Q: 找不到安全数据库？**  
A: 设置环境变量：`export SENTINELCLAW_WORKSPACE=/path/to/workspace`

**Q: 扫描器报告权限错误？**  
A: 确保脚本有执行权限：`chmod +x ~/.openclaw/sentinelclaw/scripts/*.sh`
