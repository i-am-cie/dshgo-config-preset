# dshgo-config-preset 设计文档

## 项目目标
为 DSH 手机版（dsh-go）提供开箱即用的配置预设集与一键部署脚本，降低新用户上手门槛。

---

## 1. 仓库结构

```
dshgo-config-preset/
├── presets/
│   ├── default.json          # 默认全量预设
│   ├── minimal.json          # 极简预设（仅核心插件）
│   └── dev.json              # 开发者预设（含调试工具）
├── scripts/
│   ├── install.sh            # 一键安装脚本（Linux/macOS/Termux）
│   ├── install.ps1           # Windows PowerShell 安装脚本
│   └── utils.sh              # 共享工具函数
├── docs/
│   ├── PRESETS.md            # 预设字段说明
│   ├── USAGE.md              # 使用指南
│   └── SCREENSHOTS/          # 效果截图
├── .github/
│   └── workflows/
│       └── validate.yml      # CI 校验：JSON 语法、Schema 校验、脚本语法
├── schema/
│   └── preset.schema.json    # 预设 JSON Schema
├── README.md
├── LICENSE
└── package.json              # 仅用于脚本依赖管理（如有）
```

---

## 2. 预设字段定义（`presets/*.json`）

### 2.1 顶层结构
```json
{
  "version": "1.0",
  "name": "default",
  "description": "默认全量预设，含常用插件、模型接口、UI配置、自动化任务",
  "plugins": [],
  "modelProfiles": [],
  "ui": {},
  "automations": [],
  "hooks": {}
}
```

### 2.2 插件列表（`plugins`）
每项包含：
- `id`: 插件标识（对应 dsh-go 插件目录名）
- `enabled`: 是否启用
- `config`: 插件特定配置（可选）
- `source`: 安装来源（`local`/`github`/`npm`）
- `repo`: GitHub 仓库（如 `owner/repo`）
- `branch`: 分支/标签（可选）

**内置常用插件**：
- `dsh-free-search`：统一搜索接口
- `dsh-image-gen`：生图/改图
- `dsh-mnemon`：长期记忆
- `dsh-go-plugin`：原生插件开发
- `cc-safety-net`：危险命令拦截
- `billion-context`：上下文压缩

### 2.3 模型接口配置（`modelProfiles`）
每项包含：
- `id`: 唯一标识
- `name`: 显示名称
- `provider`: `openai` | `ollama` | `openai-compat` | `anthropic` | `google` | `deepseek` 等
- `baseUrl`: API 基础地址（兼容层必填）
- `apiKeyRef`: 环境变量名（如 `DSH_SECRET_OPENAI_KEY`）
- `models`: 可用模型列表（`[{id, name, contextLength, supportsTools}]`）
- `defaultModel`: 默认模型 ID

**预置模板**：
- OpenAI 官方
- Azure OpenAI
- Ollama 本地
- DeepSeek 官方
- 通用 OpenAI 兼容层（OneAPI、LiteLLM 等）

### 2.4 UI 配置（`ui`）—— **前端负责**
对应 `~/.dsh/dsh-go/ui.json`，包含：
- `topBar`: 顶栏按钮可见性/顺序
- `capsules`: 输入框上方胶囊（快捷动作）
- `theme`: `light` | `dark` | `system` | `custom`
- `accentColor`: 强调色（HEX）
- `density`: `compact` | `comfortable` | `spacious`
- `drawer`: 抽屉分组/排序
- `hiddenElements`: 隐藏的 UI 元素 ID 列表
- `tabletShortcuts`: 平板快捷键映射
- `pluginSeats`: 插件面板座位分配

**默认预设值**：见 `presets/default.json` 中的 `ui` 字段。

### 2.5 自动化任务模板（`automations`）
每项包含：
- `id`: 唯一标识
- `name`: 显示名称
- `trigger`: `cron` | `event` | `manual`
- `cronExpression`: cron 表达式（trigger=cron 时）
- `event`: 事件名（trigger=event 时，如 `session_start`、`message_received`）
- `action`: 要执行的动作（内置动作引用或脚本路径）
- `enabled`: 是否默认启用

**内置模板**：
- 每日早报（定时触发）
- 会话自动摘要（事件触发）
- 定时清理缓存
- Git 仓库自动拉取

### 2.6 Hooks（`hooks`）
- `preInstall`: 安装前执行
- `postInstall`: 安装后执行
- `preReload`: 重载前执行
- `postReload`: 重载后执行

---

## 3. 部署脚本流程（`scripts/install.sh`）

### 3.1 环境检测
- 检测 OS：Linux / macOS / Termux(Android) / Windows(WSL/Git Bash)
- 检测 dsh-go 安装路径（`$DSH_HOME` 或默认 `~/.dsh`）
- 检测必需工具：`curl`、`git`、`jq`、`bash`、`python3`（可选）
- 检测 Node.js/pnpm（插件安装可能需要）

### 3.2 交互式选择
- 选择预设：`default` / `minimal` / `dev` / 自定义路径
- 选择模型接口模板（可跳过）
- 确认覆盖现有配置（备份原配置到 `.bak`）

### 3.3 执行步骤
1. **备份原配置**：`cp -r "$DSH_HOME/dsh-go" "$DSH_HOME/dsh-go.bak.$(date +%s)"`
2. **写入 ui.json**：合并预设 `ui` 字段到现有配置（深度合并，保留用户自定义）
3. **安装插件**：
   - `source=github`：`dsh plugin --profile web add github:owner/repo[@branch]`
   - `source=local`：复制到 `$DSH_HOME/dsh-go/plugins/`
   - `source=npm`：`pnpm add -g pkg-name` 后注册
4. **写入模型配置**：更新 `$DSH_HOME/dsh-go/engines.json` 或对应配置文件
5. **注册自动化任务**：写入 `$DSH_HOME/dsh-go/automations.json`
6. **执行 hooks**：运行 `preReload` → 重载 dsh-go → 运行 `postReload`
7. **验证**：检查关键插件是否加载成功、模型连通性测试

### 3.4 错误处理与回滚
- 任一步骤失败 → 打印错误 → 提供回滚命令：`mv "$DSH_HOME/dsh-go.bak.xxx" "$DSH_HOME/dsh-go"`
- 关键步骤使用 `set -euo pipefail` 和 `trap` 确保原子性

---

## 4. CI 校验点（`.github/workflows/validate.yml`）

触发：`push`、`pull_request`、`workflow_dispatch`

Jobs：
1. **json-lint**：`jq empty` 校验所有 `presets/*.json` 语法
2. **schema-validate**：使用 `ajv` 校验预设符合 `schema/preset.schema.json`
3. **script-lint**：`shellcheck scripts/*.sh`、`pwsh -Command "Invoke-ScriptAnalyzer scripts/*.ps1"`
4. **install-dry-run**：在容器中跑 `scripts/install.sh --dry-run --preset default`，验证不报错
5. **docs-check**：确认 `docs/PRESETS.md` 与 `schema/` 同步

---

## 5. 发布方式

- **GitHub Release**：每次合并到 `main` 自动打 Tag `vX.Y.Z`，生成 Release Notes
- **一键安装命令**：
  ```bash
  curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh | bash
  ```
- **版本策略**：SemVer，预设变更为 Minor，脚本修复为 Patch

---

## 6. 前端侧交付清单

| 项 | 文件/位置 | 说明 |
|----|-----------|------|
| 默认 UI 预设 | `presets/default.json` → `ui` | 完整 ui.json 配置 |
| 极简 UI 预设 | `presets/minimal.json` → `ui` | 仅核心胶囊、默认主题 |
| 开发者 UI 预设 | `presets/dev.json` → `ui` | 含调试面板、开发者工具 |
| 预设字段文档 | `docs/PRESETS.md` | ui 字段逐项说明、示例 |
| 效果截图 | `docs/SCREENSHOTS/` | 应用预设前后对比图 |

---

## 7. 里程碑

| 阶段 | 产出 | 负责 |
|------|------|------|
| M1: 设计定稿 | `DESIGN.md`、Schema、仓库骨架 | @程序员 @前端 |
| M2: 核心实现 | 预设 JSON、安装脚本、CI | @程序员 |
| M3: UI 预设与文档 | `ui` 字段、PRESETS.md、截图 | @前端 |
| M4: 发布验证 | Release、一键安装测试 | @程序员 @前端 |

---

## 8. 待确认事项

1. 是否需要支持 **多用户隔离**（同设备多账号）？
2. 插件安装是否默认 **启用自动更新**？
3. 模型接口配置是否要 **加密存储 API Key**（引用 Secret）？
4. 是否需要 **预设市场**（远程拉取社区预设）？
5. Windows 原生（非 WSL）支持优先级？

---

> 本文档为设计草案，待 @Chief 确认后进入实现阶段。