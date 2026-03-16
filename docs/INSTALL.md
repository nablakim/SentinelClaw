# 安装指南

## 系统要求

- Linux/macOS 系统
- Bash 4.0+
- OpenClaw (可选但推荐)
- cron (用于自动化任务)

## 快速安装

```bash
git clone https://github.com/yourusername/sentinelclaw.git
cd sentinelclaw
./install.sh
```

## 手动安装

如果不想使用安装脚本，可以手动配置：

1. 复制脚本到目标目录：
```bash
mkdir -p ~/.openclaw/sentinelclaw/scripts
cp scripts/*.sh ~/.openclaw/sentinelclaw/scripts/
chmod +x ~/.openclaw/sentinelclaw/scripts/*.sh
```

2. 设置安全数据库：
```bash
cp -r security-db ~/.openclaw/sentinelclaw/
```

3. 配置 cron 任务：
```bash
crontab -e
```

添加以下行：
```
# SentinelClaw 自动化任务
30 6 * * * cd ~/.openclaw/sentinelclaw/scripts && ./intel-collector.sh --update
0 * * * * cd ~/.openclaw/sentinelclaw/scripts && ./anomaly-detector.sh
17 6 * * 1 cd ~/.openclaw/sentinelclaw/scripts && ./security-audit.sh
```

## 配置环境变量

可以设置以下环境变量来自定义行为：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `SENTINELCLAW_WORKSPACE` | 工作目录路径 | `~/.openclaw/workspace` |

示例：
```bash
export SENTINELCLAW_WORKSPACE=/custom/path/to/workspace
```

## 验证安装

运行以下命令验证安装：

```bash
~/.openclaw/sentinelclaw/scripts/roadmap-check.sh all
```

## 卸载

```bash
# 移除 cron 任务
crontab -e
# 删除 SentinelClaw 相关的行

# 删除文件
rm -rf ~/.openclaw/sentinelclaw
```
