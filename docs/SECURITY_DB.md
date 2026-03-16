# 威胁情报数据库

SentinelClaw 使用结构化的 YAML 格式存储威胁情报，便于程序化处理和社区共享。

## 目录结构

```
security-db/
├── threats/
│   ├── active/        # 活跃威胁
│   │   └── clawhavoc-2026-02.yaml
│   └── resolved/      # 已解决威胁
├── iocs/
│   ├── ips.txt        # 恶意 IP 列表
│   ├── domains.txt    # 恶意域名列表
│   └── checksums.txt  # 恶意文件哈希
└── advisories/        # 安全公告
```

## 威胁记录格式

```yaml
id: "threat-unique-id"
name: "Threat Name"
status: "active"  # active | resolved
severity: "high"  # critical | high | medium | low
discovered: "2026-02-20"
resolved: null    # 或解决日期

summary: |
  威胁的简要描述

description: |
  详细的威胁描述，包括攻击向量、影响范围等

affected:
  platforms: ["macos", "windows"]
  skills:
    - name: "malicious-skill"
      versions: ["1.0.0", "1.1.0"]
  users: "all"

indicators:
  ips: ["91.92.242.30"]
  domains: ["evil.example.com"]
  checksums: ["a1b2c3d4..."]

attack_vectors:
  - "typosquatting"
  - "fake_prerequisites"
  - "social_engineering"

mitigation:
  immediate_actions:
    - "卸载受影响技能"
    - "轮换所有凭证"
  detection:
    - "检查 ~/.openclaw/credentials 异常访问"
  prevention:
    - "使用 sentinelclaw 扫描所有技能"

references:
  - type: "report"
    url: "https://example.com/report"
  - type: "github"
    url: "https://github.com/org/advisory"
```

## IOCs 格式

### IPs (iocs/ips.txt)

```
# 格式: IP [注释]
91.92.242.30    # ClawHavoc C2
185.220.101.42  # 可疑代理
```

### Domains (iocs/domains.txt)

```
# 格式: domain [注释]
evil.example.com        # ClawHavoc 控制域
malicious.clawhub.io    # 钓鱼域名
```

### Checksums (iocs/checksums.txt)

```
# 格式: hash:type [注释]
a1b2c3d4e5f6...:sha256  # malicious-skill-v1.0.0
```

## 添加新威胁

1. 复制模板：
```bash
cp security-db/threats/template.yaml security-db/threats/active/my-threat.yaml
```

2. 编辑文件，填写详细信息

3. 验证格式：
```bash
./scripts/validate-security-db.sh
```

4. 提交到社区（如适用）

## 更新 IOCs

### 手动更新

直接编辑 `iocs/` 目录下的文件。

### 自动更新

```bash
./scripts/intel-collector.sh --update
```

## 威胁情报源

SentinelClaw 支持从以下源收集情报：

- GitHub Security Advisories
- 社区共享的威胁记录
- 本地蜜罐检测
- 用户提交的样本

## 数据验证

定期运行验证确保数据完整性：

```bash
./scripts/validate-security-db.sh
```

## 隐私考虑

- 不要提交包含个人信息的威胁记录
- 敏感 IOCs 使用私有数据库
- 公开分享前脱敏处理
