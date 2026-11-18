# 预设字段详细说明

本文档描述 `presets/*.json` 中每个字段的含义、取值范围、示例。

---

## 顶层结构

```json
{
  "version": "1.0.0",
  "name": "default",
  "description": "预设描述",
  "plugins": [],
  "modelProfiles": [],
  "ui": {},
  "automations": [],
  "hooks": {}
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| version | string | ✅ | 语义化版本号（Major.Minor.Patch） |
| name | string | ✅ | 预设唯一标识（default/minimal/dev/自定义） |
| description | string | ❌ | 人类可读的描述 |
| plugins | array | ✅ | 插件列表 |
| modelProfiles | array | ✅ | 模型接口配置列表 |
| ui | object | ✅ | UI 配置（对应 `~/.dsh/dsh-go/ui.json`） |
| automations | array | ✅ | 自动化任务模板列表 |
| hooks | object | ✅ | 生命周期钩子 |

---

## plugins：插件列表

每个插件对象：

```json
{
  "id": "dsh-free-search",
  "enabled": true,
  "config": {},
  "source": "github",
  "repo": "dsh-plugins/dsh-free-search",
  "branch": "main"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | string | ✅ | 插件标识，对应 dsh-go 插件目录名 |
| enabled | boolean | ✅ | 是否启用 |
| config | object | ❌ | 插件特定配置（透传给插件） |
| source | string | ✅ | 安装来源：`local`、`github`、`npm` |
| repo | string | github 时必填 | GitHub 仓库 `owner/repo` |
| branch | string | ❌ | 分支/标签，默认 `main` |

### 内置常用插件

| ID | 来源 | 功能 |
|----|------|------|
| dsh-free-search | github | 统一搜索接口（接管 web 搜索） |
| dsh-image-gen | github | 生图/改图 |
| dsh-mnemon | github | 长期记忆 |
| dsh-go-plugin | github | 原生插件开发 |
| cc-safety-net | github | 危险命令拦截 |
| billion-context | github | 上下文压缩 |
| dsh-go-support | github | 排障与反馈 |
| dsh-go-ui | github | UI 配置编辑器 |

---

## modelProfiles：模型接口配置

每个配置对象：

```json
{
  "id": "openai-official",
  "name": "OpenAI 官方",
  "provider": "openai",
  "baseUrl": "https://api.openai.com/v1",
  "apiKeyRef": "DSH_SECRET_OPENAI_KEY",
  "models": [
    { "id": "gpt-4o", "name": "GPT-4o", "contextLength": 128000, "supportsTools": true }
  ],
  "defaultModel": "gpt-4o-mini"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | string | ✅ | 唯一标识 |
| name | string | ✅ | 显示名称 |
| provider | string | ✅ | 提供商：`openai`、`ollama`、`openai-compat`、`anthropic`、`google`、`deepseek` |
| baseUrl | string | 兼容层必填 | API 基础地址 |
| apiKeyRef | string | ✅ | 环境变量名（格式：`DSH_SECRET_XXX`） |
| models | array | ✅ | 可用模型列表（至少 1 个） |
| defaultModel | string | ✅ | 默认模型 ID（需在 models 中存在） |

### 模型对象

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | string | ✅ | 模型 API 标识 |
| name | string | ✅ | 显示名称 |
| contextLength | integer | ✅ | 上下文长度 |
| supportsTools | boolean | ✅ | 是否支持工具调用 |

### 预置模板

| ID | Provider | 适用场景 |
|----|----------|----------|
| openai-official | openai | OpenAI 官方 API |
| azure-openai | openai | Azure OpenAI 服务 |
| ollama-local | ollama | 本地 Ollama 服务 |
| deepseek-official | deepseek | DeepSeek 官方 API |
| openai-compat | openai-compat | OneAPI、LiteLLM、自建兼容层 |

---

## ui：UI 配置（前端核心负责）

对应 `~/.dsh/dsh-go/ui.json`，完整字段如下：

```json
{
  "topBar": { "visible": true, "buttons": ["new-chat", "search", "model-selector", "settings", "menu"] },
  "capsules": [
    { "id": "summarize", "label": "总结对话", "action": "summarize_session", "icon": "IconText" }
  ],
  "theme": "system",
  "accentColor": "#009688",
  "density": "comfortable",
  "drawer": { "groups": ["recent", "pinned", "projects", "agents", "plugins", "settings"], "sortBy": "updated" },
  "hiddenElements": ["footer-version", "chat-watermark"],
  "tabletShortcuts": { "Ctrl+K": "focus_search", "Ctrl+N": "new_chat" },
  "pluginSeats": { "search": "dsh-free-search", "image": "dsh-image-gen", "memory": "dsh-mnemon", "tools": "dsh-go-plugin" }
}
```

### topBar：顶栏

| 字段 | 类型 | 说明 |
|------|------|------|
| visible | boolean | 是否显示顶栏 |
| buttons | array[string] | 按钮 ID 列表，顺序即显示顺序 |

**可用按钮 ID**：
- `new-chat`：新建对话
- `search`：搜索
- `model-selector`：模型选择器
- `terminal`：终端
- `plugins`：插件面板
- `settings`：设置
- `menu`：更多菜单

### capsules：输入框上方胶囊

每个胶囊对象：

```json
{
  "id": "summarize",
  "label": "总结对话",
  "action": "summarize_session",
  "icon": "IconText"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | string | ✅ | 唯一标识 |
| label | string | ✅ | 显示文本 |
| action | string | ✅ | 动作标识（内置动作或插件动作） |
| icon | string | ❌ | 图标名称（TinyIcon 名称） |

**内置动作**：
- `summarize_session`：总结当前会话
- `translate_selection`：翻译选中文本
- `explain_code`：解释代码
- `save_to_notes`：存入笔记
- `speak_last_reply`：朗读最后一条回复
- `show_debug_info`：显示调试信息
- `reload_plugins`：重载插件
- `open_terminal`：打开终端

**可用图标**：`IconText`、`IconWorld`、`IconCode`、`IconPlusCircle`、`IconVolume`、`IconBug`、`IconRefresh`、`IconTerminal`、`IconSearch`、`IconSetting`、`IconStarO` 等（见 TinyIcon 组件）

### theme：主题

| 值 | 说明 |
|----|------|
| `light` | 浅色模式 |
| `dark` | 深色模式 |
| `system` | 跟随系统 |
| `custom` | 自定义（需配合 accentColor） |

### accentColor：强调色

HEX 格式，如 `#009688`、`#6366F1`、`#F59E0B`。

### density：密度

| 值 | 说明 |
|----|------|
| `compact` | 紧凑 |
| `comfortable` | 舒适（默认） |
| `spacious` | 宽松 |

### drawer：抽屉

| 字段 | 类型 | 说明 |
|------|------|------|
| groups | array[string] | 分组 ID 列表，顺序即显示顺序 |
| sortBy | string | 排序方式：`name`、`created`、`updated` |

**可用分组 ID**：
- `recent`：最近会话
- `pinned`：置顶会话
- `projects`：项目
- `agents`：智能体
- `plugins`：插件
- `tools`：工具
- `settings`：设置

### hiddenElements：隐藏元素

元素 ID 列表，常用：
- `footer-version`：底部版本号
- `chat-watermark`：聊天水印
- `plugin-panel`：插件面板入口

### tabletShortcuts：平板快捷键

键值对，键为快捷键（如 `Ctrl+K`），值为动作 ID。

**可用动作**：
- `focus_search`：聚焦搜索
- `new_chat`：新建对话
- `toggle_drawer`：切换抽屉
- `command_palette`：命令面板
- `open_terminal`：打开终端
- `reload_plugins`：重载插件
- `toggle_dev_tools`：切换开发者工具

### pluginSeats：插件面板座位

键值对，键为座位 ID，值为插件 ID。决定插件在面板中的位置。

---

## automations：自动化任务模板

每个任务对象：

```json
{
  "id": "daily-brief",
  "name": "每日早报",
  "trigger": "cron",
  "cronExpression": "0 8 * * *",
  "action": "builtin:daily_brief",
  "enabled": true
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | string | ✅ | 唯一标识 |
| name | string | ✅ | 显示名称 |
| trigger | string | ✅ | 触发类型：`cron`、`event`、`manual` |
| cronExpression | string | cron 时必填 | 标准 cron 表达式（分 时 日 月 周） |
| event | string | event 时必填 | 事件名：`session_start`、`session_end`、`message_received`、`app_start` |
| action | string | ✅ | 动作引用：`builtin:xxx`、`script:xxx.sh` |
| enabled | boolean | ✅ | 默认是否启用 |

### 内置动作

| 动作 | 说明 |
|------|------|
| `builtin:daily_brief` | 生成每日早报 |
| `builtin:summarize_session` | 总结会话 |
| `builtin:cleanup_cache` | 清理缓存 |
| `builtin:check_plugin_updates` | 检查插件更新 |

### Cron 表达式示例

| 表达式 | 含义 |
|--------|------|
| `0 8 * * *` | 每天 08:00 |
| `0 3 * * 0` | 每周日 03:00 |
| `0 */6 * * *` | 每 6 小时 |
| `0 2 * * *` | 每天 02:00 |

---

## hooks：生命周期钩子

```json
{
  "preInstall": ["echo '开始安装...'"],
  "postInstall": ["echo '安装完成'"],
  "preReload": ["dsh-go-cli save-state"],
  "postReload": ["dsh-go-cli notify '配置已更新'"]
}
```

| 阶段 | 触发时机 |
|------|----------|
| preInstall | 安装脚本开始前 |
| postInstall | 所有配置写入后、重载前 |
| preReload | 发送重载信号前 |
| postReload | 重载完成后 |

每个阶段为命令数组，顺序执行。支持任意 Shell 命令。

---

## 完整示例：default 预设

见 `presets/default.json`，包含：
- 6 个核心插件
- 4 套模型接口模板
- 5 个 UI 胶囊
- 4 个自动化任务
- 完整 UI 配置（主题、密度、抽屉、快捷键、插件座位）

---

## 校验工具

```bash
# 语法检查
jq empty presets/default.json

# Schema 校验
ajv validate -s schema/preset.schema.json -d presets/default.json

# 干跑安装
bash scripts/install.sh --preset default --dry-run --yes
```