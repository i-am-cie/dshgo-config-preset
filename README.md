# dshgo-config-preset

> 为 DSH 手机版（dsh-go）提供开箱即用的配置预设集与一键部署脚本，让新用户「装完即用」。

[![GitHub Release](https://img.shields.io/github/v/release/i-am-cie/dshgo-config-preset)](https://github.com/i-am-cie/dshgo-config-preset/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![dsh-go](https://img.shields.io/badge/dsh--go-compatible-brightgreen)](https://github.com/deepseek-ai/dsh-go)

---

## ✨ 特性

- **三套预设**：`default`（全量）、`minimal`（极简）、`dev`（开发者）
- **一键安装**：单条命令完成环境检测、配置写入、插件安装、重载
- **模型接口预置**：OpenAI、Ollama、DeepSeek、通用兼容层
- **UI 配置预设**：胶囊、主题、顶栏、抽屉、快捷键、插件座位
- **自动化任务**：每日早报、会话摘要、缓存清理、Git 拉取
- **CI 校验**：JSON 语法、Schema 校验、Shell/PowerShell Lint、安装干跑
- **自动发布**：推送到 main 自动打 Tag、生成 Release、更新安装脚本

---

## 🚀 快速开始

### 一键安装（推荐）

```bash
# 默认全量预设
curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh | bash

# 指定预设
curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh | bash -s -- --preset minimal
curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh | bash -s -- --preset dev

# 完整参数示例
bash <(curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh) \
  --preset dev \
  --model-profile ollama-local \
  --yes
```

### 手动安装

```bash
git clone https://github.com/i-am-cie/dshgo-config-preset.git
cd dshgo-config-preset
bash scripts/install.sh --preset default --yes
```

---

## 📦 预设对比

| 特性 | `default` | `minimal` | `dev` |
|------|-----------|-----------|-------|
| 核心插件 | ✅ 6 个 | ✅ 2 个 | ✅ 8 个 |
| 模型接口 | ✅ 4 套 | ✅ 1 套 | ✅ 4 套 |
| UI 胶囊 | 5 个 | 2 个 | 8 个 |
| 自动化任务 | 4 个 | 1 个 | 5 个 |
| 主题 | system | system | dark |
| 密度 | comfortable | comfortable | compact |
| 调试工具 | ❌ | ❌ | ✅ |

---

## 📁 仓库结构

```
dshgo-config-preset/
├── presets/
│   ├── default.json    # 默认全量预设
│   ├── minimal.json    # 极简预设
│   └── dev.json        # 开发者预设
├── scripts/
│   ├── install.sh      # Linux/macOS/Termux 安装脚本
│   ├── install.ps1     # Windows PowerShell 安装脚本
│   └── utils.sh        # 共享工具函数
├── schema/
│   └── preset.schema.json  # JSON Schema 校验
├── docs/
│   ├── PRESETS.md      # 预设字段说明
│   ├── USAGE.md        # 使用指南
│   └── SCREENSHOTS/    # 效果截图
├── .github/workflows/
│   └── validate.yml    # CI 校验流程
├── README.md
└── LICENSE
```

---

## ⚙️ 配置说明

详见 [docs/PRESETS.md](docs/PRESETS.md)

### 预设字段

- **plugins**：插件列表（来源、启用状态、配置）
- **modelProfiles**：模型接口配置（提供商、BaseURL、API Key 引用、模型列表）
- **ui**：UI 配置（顶栏、胶囊、主题、密度、抽屉、快捷键、插件座位）
- **automations**：自动化任务模板
- **hooks**：安装/重载钩子

### 环境变量（API Key）

安装脚本使用环境变量引用存储 API Key，不写入明文：

```bash
export DSH_SECRET_OPENAI_KEY="sk-..."
export DSH_SECRET_DEEPSEEK_KEY="sk-..."
export DSH_SECRET_OLLAMA_KEY="local"  # Ollama 通常无需 Key
export DSH_SECRET_COMPAT_KEY="sk-..."  # 兼容层 Key
```

---

## 🛠️ 开发指南

### 本地验证

```bash
# JSON 语法检查
jq empty presets/*.json

# Schema 校验
npm install -g ajv-cli
ajv validate -s schema/preset.schema.json -d presets/default.json

# Shell 脚本检查
shellcheck scripts/*.sh

# 干跑测试
DSH_HOME=/tmp/dsh-test bash scripts/install.sh --preset default --dry-run --yes
```

### 添加新预设

1. 在 `presets/` 下创建 `xxx.json`（参考现有预设结构）
2. 运行 Schema 校验确保格式正确
3. 更新 `scripts/install.sh` 中的 `PRESET_FILES` 映射
4. 提交 PR，CI 自动验证

---

## 📸 效果预览

| 应用前 | 应用后 (default) |
|--------|------------------|
| ![before](docs/SCREENSHOTS/before.png) | ![after-default](docs/SCREENSHOTS/after-default.png) |

> 截图位于 `docs/SCREENSHOTS/`，PR 欢迎补充！

---

## 🤝 贡献

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feat/new-preset`
3. 提交变更：`git commit -am 'Add new preset: xxx'`
4. 推送分支：`git push origin feat/new-preset`
5. 发起 Pull Request

---

## 📄 许可证

MIT License © 2024 i-am-cie

---

## 🔗 相关链接

- [dsh-go 官方仓库](https://github.com/deepseek-ai/dsh-go)
- [DSH 文档](https://deepseek.com/dsh)
- [问题反馈](https://github.com/i-am-cie/dshgo-config-preset/issues)