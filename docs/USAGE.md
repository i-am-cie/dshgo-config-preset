# 使用指南

本文档说明如何使用 `dshgo-config-preset` 为 dsh-go 快速配置开箱即用的环境。

---

## 安装前准备

### 系统要求
- **操作系统**：Linux / macOS / Windows (WSL/Git Bash/PowerShell) / Termux (Android)
- **已安装 dsh-go**：参考 [dsh-go 官方安装指南](https://github.com/deepseek-ai/dsh-go)
- **必要工具**：`curl`、`git`、`jq`、`bash` (或 PowerShell 7+)

### 推荐预安装
```bash
# Ubuntu/Debian
sudo apt-get install curl git jq bash

# macOS
brew install curl git jq bash

# Termux
pkg install curl git jq bash

# Windows (Scoop)
scoop install curl git jq bash
```

---

## 快速安装

### 方式一：一键安装（推荐）

```bash
# 默认全量预设
curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh | bash

# 极简预设
curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh | bash -s -- --preset minimal

# 开发者预设
curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh | bash -s -- --preset dev
```

### 方式二：克隆仓库后安装

```bash
git clone https://github.com/i-am-cie/dshgo-config-preset.git
cd dshgo-config-preset

# 默认预设，交互式确认
bash scripts/install.sh

# 指定预设，自动确认
bash scripts/install.sh --preset default --yes

# 指定预设 + 预选模型 + 自动确认
bash scripts/install.sh --preset dev --model-profile ollama-local --yes

# 仅模拟运行（不写入文件）
bash scripts/install.sh --preset default --dry-run
```

### 方式三：Windows PowerShell

```powershell
# 默认预设
irm https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.ps1 | iex

# 指定预设
irm https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.ps1 | iex --preset dev

# 完整参数
& (irm https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.ps1) -Preset dev -ModelProfile ollama-local -Yes
```

---

## 安装参数详解

| 参数 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--preset` | - | 预设名称：`default`、`minimal`、`dev` | `default` |
| `--model-profile` | - | 预选模型接口 ID（跳过交互选择） | 无 |
| `--dry-run` | - | 仅模拟运行，不写入文件 | false |
| `--yes`, `-y` | - | 自动确认所有提示 | false |
| `--force` | - | 强制覆盖，不备份原配置 | false |
| `--help`, `-h` | - | 显示帮助信息 | - |

---

## 安装后配置

### 1. 配置模型 API Key

安装脚本使用环境变量引用存储 API Key，**不会将明文写入配置文件**。

```bash
# 编辑 shell 配置文件
vim ~/.bashrc  # 或 ~/.zshrc, ~/.config/fish/config.fish

# 添加以下环境变量（根据需要选择）
export DSH_SECRET_OPENAI_KEY="sk-xxxxxxxxxxxx"
export DSH_SECRET_DEEPSEEK_KEY="sk-xxxxxxxxxxxx"
export DSH_SECRET_OLLAMA_KEY="local"  # Ollama 本地通常无需 Key
export DSH_SECRET_COMPAT_KEY="sk-xxxxxxxxxxxx"  # 兼容层 Key

# 重新加载配置
source ~/.bashrc
```

> **注意**：环境变量名必须为 `DSH_SECRET_` 前缀，这是 dsh-go 约定的 Secret 引用格式。

### 2. 重启 dsh-go

安装脚本会尝试发送重载信号，但建议**完全重启 dsh-go App** 以确保所有配置生效。

- **手机端**：从后台杀掉进程，重新打开 App
- **桌面端/终端**：`pkill -f dsh-go && dsh-go &`

### 3. 验证安效果

打开 dsh-go，检查：
- ✅ 顶栏按钮是否符合预设
- ✅ 输入框上方胶囊是否显示
- ✅ 主题/密度/抽屉分组是否生效
- ✅ 插件面板座位是否对应
- ✅ 设置 → 模型中是否出现预置模型接口
- ✅ 设置 → 自动化任务中是否有预置任务

---

## 常见问题

### Q: 安装脚本提示 "未找到 dsh-go 目录"
**A**: 确保已安装 dsh-go，或手动指定 `DSH_HOME`：
```bash
export DSH_HOME="/path/to/your/dsh"
bash scripts/install.sh --preset default
```

### Q: 插件安装失败
**A**: 
- 检查网络连通性（GitHub 访问）
- 确保 `dsh` CLI 可用：`dsh --version`
- 手动安装：`dsh plugin --profile web add github:owner/repo@branch`

### Q: 模型接口不生效
**A**: 
- 确认环境变量 `DSH_SECRET_XXX` 已正确设置并重新加载 shell
- 在 dsh-go 设置 → 模型中手动测试连接
- 查看日志：`dsh-go-cli logs`

### Q: 想要自定义预设
**A**: 
1. 复制现有预设：`cp presets/default.json presets/my-custom.json`
2. 修改字段
3. 校验：`ajv validate -s schema/preset.schema.json -d presets/my-custom.json`
4. 安装：`bash scripts/install.sh --preset my-custom`

### Q: 如何卸载/回滚
**A**: 安装脚本会自动备份原配置到 `~/.dsh/dsh-go.bak.<timestamp>`：
```bash
# 回滚到最近备份
mv ~/.dsh/dsh-go.bak.$(ls -t ~/.dsh/dsh-go.bak.* | head -1 | xargs basename) ~/.dsh/dsh-go

# 或手动指定备份文件
mv ~/.dsh/dsh-go.bak.1700000000 ~/.dsh/dsh-go
```

---

## 高级用法

### 组合多个预设
安装脚本每次只应用一个预设。如需组合，可：
1. 先应用 `minimal` 预设
2. 手动合并 `default` 预设中需要的插件/配置
3. 或编写自定义预设 JSON

### CI/CD 集成
在自动化部署中使用：
```yaml
# GitHub Actions 示例
- name: Apply dshgo preset
  run: |
    export DSH_SECRET_OPENAI_KEY="${{ secrets.OPENAI_KEY }}"
    export DSH_SECRET_DEEPSEEK_KEY="${{ secrets.DEEPSEEK_KEY }}"
    bash scripts/install.sh --preset default --yes --model-profile openai-official
```

### 离线安装
1. 克隆仓库到目标机器
2. 将插件仓库预下载到本地
3. 修改预设 `source: local`，指向本地路径
3. 运行安装脚本

---

## 获取帮助

- **查看脚本帮助**：`bash scripts/install.sh --help`
- **提交 Issue**：[GitHub Issues](https://github.com/i-am-cie/dshgo-config-preset/issues)
- **dsh-go 官方文档**：[deepseek.com/dsh](https://deepseek.com/dsh)