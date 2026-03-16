# Contributing to SentinelClaw

感谢您对 SentinelClaw 的兴趣！以下是参与贡献的指南。

## 如何贡献

### 报告问题

如果您发现了 bug 或有功能建议：

1. 先搜索现有 issues，避免重复
2. 创建新 issue，包含：
   - 问题描述
   - 复现步骤（如适用）
   - 环境信息（OS, OpenClaw 版本等）
   - 预期行为 vs 实际行为

### 提交代码

1. Fork 仓库
2. 创建功能分支：`git checkout -b feature/my-feature`
3. 提交更改：`git commit -am 'Add some feature'`
4. 推送分支：`git push origin feature/my-feature`
5. 创建 Pull Request

### 代码规范

- 使用 bash 编写脚本
- 添加适当的注释
- 确保脚本可移植（避免硬编码路径）
- 测试您的更改

### 文档贡献

文档改进同样重要！包括：
- 修正错别字
- 改进说明
- 添加示例
- 翻译

## 开发设置

```bash
git clone https://github.com/yourusername/sentinelclaw.git
cd sentinelclaw

# 测试脚本
./tests/run-tests.sh
```

## 行为准则

请遵守 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

## 联系方式

- Issues: [GitHub Issues](https://github.com/yourusername/sentinelclaw/issues)
- Discussions: [GitHub Discussions](https://github.com/yourusername/sentinelclaw/discussions)

感谢您的贡献！
