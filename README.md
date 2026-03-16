# 🛡️ SentinelClaw

> **Agent as Runtime 防御体系** — 不是工具，是系统。

SentinelClaw 是一套嵌入 OpenClaw Agent Runtime 的自动化安全防御系统。它在你睡觉的时候继续运行，在你忘记它存在的时候继续保护。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 核心定位

| 传统安全工具 | SentinelClaw |
|-------------|--------------|
| 外部扫描器，手动调用 | 嵌入 Runtime，自动化运行 |
| 检测后告警 | 持续监控，自动适应 |
| 需要安全专业知识 | 开箱即用，零配置 |
| 越攻击越弱 | 越攻击越强（反脆弱） |

**三大核心特性：**
- 🤖 **自动化** — 安装后无需任何手动操作
- 🎯 **主动化** — 情报自收集，主动狩猎威胁
- 🌱 **自举性** — 系统监控自身，自我迭代进化

---

## 快速开始

### 安装

```bash
git clone https://github.com/yourusername/sentinelclaw.git
cd sentinelclaw
./install.sh
```

安装完成后，SentinelClaw 会自动配置 3 个定时任务：

| 任务 | 频率 | 功能 |
|------|------|------|
| 威胁情报收集 | 每天 6:30 | 自动更新 IOCs 和威胁情报 |
| 异常检测 | 每小时 | 监控凭证、网络、文件系统异常 |
| 安全审计 | 每周一 6:17 | 深度系统安全审计 |

### 安全安装技能（推荐）

```bash
# 使用 SentinelClaw 安全包装器安装技能
./scripts/safe-install.sh weather

# 或直接扫描后手动安装
./scripts/scan-skill.sh /path/to/skill -v
```

---

## 系统架构

```
┌─────────────────────────────────────────────────────────┐
│                   SentinelClaw 防御体系                  │
├─────────────────────────────────────────────────────────┤
│  自动化层                                                │
│  ├── 每周审计 (周一 6:17)                                │
│  ├── 每日情报 (6:30 AM)                                 │
│  └── 每小时检测 (整点)                                   │
├─────────────────────────────────────────────────────────┤
│  工具层                                                  │
│  ├── scan-skill.sh      → 静态扫描                      │
│  ├── monitor-skill.sh   → 行为监控                      │
│  ├── safe-install.sh    → 安全安装                      │
│  ├── intel-collector.sh → 情报收集                      │
│  └── anomaly-detector.sh → 异常检测                     │
├─────────────────────────────────────────────────────────┤
│  数据层                                                  │
│  ├── security-db/        → 结构化威胁情报                │
│  └── .security-backups/  → 备份与基线                   │
├─────────────────────────────────────────────────────────┤
│  回滚层                                                  │
│  └── security-backup.sh → 一键回滚                      │
└─────────────────────────────────────────────────────────┘
```

---

## 核心组件

### 1. 技能安全扫描 (`scan-skill.sh`)
静态分析技能包，检测：
- 恶意代码模式（反向 shell、数据窃取）
- 可疑网络请求
- 凭证访问行为
- 权限提升尝试

### 2. 行为监控 (`monitor-skill.sh`)
建立正常行为基线，检测偏离：
- 网络连接异常
- 文件系统访问异常
- 凭证访问模式变化

### 3. 安全安装包装器 (`safe-install.sh`)
一键安全安装流程：
```
扫描 → 基线 → 安装 → 验证
```

### 4. 情报收集器 (`intel-collector.sh`)
主动收集威胁情报：
- 在线威胁源检查
- ClawHavoc 等已知威胁 IOCs
- 已安装技能的风险评估

### 5. 异常检测器 (`anomaly-detector.sh`)
实时监控系统异常：
- 凭证文件访问监控
- 网络连接监控
- 技能变更检测
- 日志异常分析

### 6. 备份与恢复 (`security-backup.sh`)
完整备份机制：
- 自动保留最近 5 个版本
- 一键回滚到任意历史版本

---

## S.T.A.R.S. 方法论

SentinelClaw 基于 S.T.A.R.S. 安全框架构建：

| 阶段 | 含义 | 组件 |
|------|------|------|
| **S**urvey | 情报收集 | intel-collector.sh, security-db/ |
| **T**hreat Model | 威胁建模 | scan-skill.sh, anomaly-detector.sh |
| **A**rchive | 归档备份 | security-backup.sh, pre-modify-hook.sh |
| **R**outine | 例行监控 | monitor-skill.sh, cron 任务 |
| **S**afeguard | 安全保护 | safe-install.sh, 多层防御 |

---

## 与现有方案的关系

SentinelClaw 不是 [Clawned](https://clawned.io) 或 [Cisco Skill Scanner](https://github.com/cisco-ai-defense/skill-scanner) 的竞争对手，而是**互补层**：

| 场景 | 推荐方案 |
|------|----------|
| 企业级深度扫描 | Cisco Skill Scanner |
| 云端实时监控 | Clawned |
| 离线/隔离环境 | **SentinelClaw** ✅ |
| 零配置自动化保护 | **SentinelClaw** ✅ |
| 学习/教学目的 | **SentinelClaw** ✅ |

---

## 反脆弱性

传统系统：**越攻击越弱**

SentinelClaw：**越攻击越强**

每一次新的威胁情报、每一次攻击尝试，都被系统吸收为进化素材：
1. 情报收集器将新威胁纳入数据库
2. 异常检测器更新行为基线
3. 扫描器学习新的恶意模式

> "威胁不是风险，是信息。信息让系统进化。"

---

## 文档

- [安装指南](docs/INSTALL.md)
- [使用手册](docs/USAGE.md)
- [S.T.A.R.S. 框架详解](docs/STARS.md)
- [威胁情报数据库](docs/SECURITY_DB.md)
- [贡献指南](CONTRIBUTING.md)

---

## 贡献

欢迎贡献！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解如何参与。

---

## 许可证

MIT License — 详见 [LICENSE](LICENSE)

---

🔷 **SentinelClaw — 让 OpenClaw 自我保护**
