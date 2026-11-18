#!/usr/bin/env pwsh
<#
.SYNOPSIS
    dshgo-config-preset 一键安装脚本
.DESCRIPTION
    为 DSH 手机版（dsh-go）提供开箱即用的配置预设集与一键部署
.NOTES
    Author: i-am-cie
    Repository: https://github.com/i-am-cie/dshgo-config-preset
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('default', 'minimal', 'dev')]
    [string]$Preset = 'default',

    [Parameter()]
    [string]$ModelProfile = '',

    [Parameter()]
    [switch]$DryRun = $false,

    [Parameter()]
    [alias('y')]
    [switch]$Yes = $false,

    [Parameter()]
    [switch]$Force = $false,

    [Parameter()]
    [switch]$Help = $false
)

# ==================== 常量配置 ====================
$REPO_OWNER = "i-am-cie"
$REPO_NAME = "dshgo-config-preset"
$REPO_BRANCH = "main"
$RAW_BASE = "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$REPO_BRANCH"

$PRESET_FILES = @{
    'default' = 'presets/default.json'
    'minimal' = 'presets/minimal.json'
    'dev' = 'presets/dev.json'
}

# ==================== 颜色输出 ====================
function Write-Info  { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "[OK]    $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Step  { Write-Host "[STEP]  $args" -ForegroundColor Magenta }

# ==================== 帮助信息 ====================
if ($Help) {
    @"
用法: .\install.ps1 [选项]

选项:
  -Preset <name>       选择预设: default | minimal | dev (默认: default)
  -ModelProfile <id>   预选模型接口配置 (跳过交互)
  -DryRun              仅模拟运行，不写入文件
  -Yes, -y             自动确认所有提示
  -Force               强制覆盖，不备份原配置
  -Help                显示帮助

示例:
  .\install.ps1 -Preset dev -Yes
  .\install.ps1 -Preset minimal -ModelProfile ollama-local
"@
    exit 0
}

# ==================== 预设验证 ====================
if (-not $PRESET_FILES.ContainsKey($Preset)) {
    Write-Error "无效预设: $Preset (可选: $($PRESET_FILES.Keys -join ', '))"
    exit 1
}
$PRESET_FILE = $PRESET_FILES[$Preset]

# ==================== 环境检测 ====================
function Detect-OS {
    $os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
    if ($IsLinux) { $global:OS = 'linux' }
    elseif ($IsMacOS) { $global:OS = 'macos' }
    elseif ($IsWindows) { $global:OS = 'windows' }
    else { $global:OS = 'unknown' }

    # Termux (Android) 检测
    if ($env:TERMUX_VERSION -or (Test-Path "/data/data/com.termux")) {
        $global:OS = 'termux'
    }

    Write-Info "检测到操作系统: $global:OS"
}

function Detect-DshHome {
    if ($env:DSH_HOME -and (Test-Path $env:DSH_HOME)) {
        $global:DSH_HOME = $env:DSH_HOME
    }
    elseif (Test-Path "$HOME/.dsh") {
        $global:DSH_HOME = "$HOME/.dsh"
    }
    elseif (Test-Path "/opt/dsh") {
        $global:DSH_HOME = "/opt/dsh"
    }
    else {
        $global:DSH_HOME = "$HOME/.dsh"
        Write-Warn "未找到 DSH_HOME，使用默认: $global:DSH_HOME"
    }

    if (-not (Test-Path "$global:DSH_HOME/dsh-go")) {
        Write-Warn "dsh-go 目录不存在: $global:DSH_HOME/dsh-go (安装脚本将创建)"
    }

    Write-Info "DSH_HOME: $global:DSH_HOME"
}

function Check-Dependencies {
    $missing = @()
    foreach ($cmd in 'curl', 'git', 'jq', 'bash') {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $missing += $cmd
        }
    }

    if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
        Write-Warn "未找到 python3，部分插件可能无法安装"
    }

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Warn "未找到 Node.js，npm 源插件将跳过"
    }

    if ($missing.Count -gt 0) {
        Write-Error "缺少必要工具: $($missing -join ', ')"
        Write-Error "请先安装后再运行此脚本"
        exit 1
    }

    Write-Ok "依赖检查通过"
}

# ==================== 下载预设 ====================
function Fetch-Preset {
    $url = "$RAW_BASE/$PRESET_FILE"
    Write-Step "下载预设: $url"

    if ($DryRun) {
        Write-Info "[DRY-RUN] 跳过下载"
        return
    }

    try {
        $global:PRESET_JSON = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing
    }
    catch {
        Write-Error "下载预设失败: $url"
        Write-Error $_.Exception.Message
        exit 1
    }

    # 校验 JSON 语法
    try {
        $global:PRESET_JSON | ConvertFrom-Json | ConvertTo-Json | Out-Null
    }
    catch {
        Write-Error "预设 JSON 语法错误"
        exit 1
    }

    Write-Ok "预设下载并校验通过"
}

# ==================== 交互式确认 ====================
function Confirm-Install {
    if ($Yes) { return }

    Write-Host ""
    Write-Info "即将应用预设: $Preset"
    Write-Info "目标目录: $global:DSH_HOME/dsh-go"
    Write-Host ""

    $pluginCount = ($global:PRESET_JSON | ConvertFrom-Json).plugins.Count
    $modelCount = ($global:PRESET_JSON | ConvertFrom-Json).modelProfiles.Count
    Write-Info "包含插件: $pluginCount 个"
    Write-Info "模型接口: $modelCount 个"

    if ($ModelProfile) {
        Write-Info "预选模型: $ModelProfile"
    }

    Write-Host ""
    $confirm = Read-Host "确认继续? [y/N]"
    if (-not $confirm -or $confirm.ToLower() -ne 'y') {
        Write-Info "已取消"
        exit 0
    }
}

# ==================== 备份原配置 ====================
function Backup-Config {
    if ($Force) {
        Write-Warn "-Force 模式，跳过备份"
        return
    }

    $backupDir = "$global:DSH_HOME/dsh-go.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Write-Step "备份原配置到: $backupDir"

    if ($DryRun) {
        Write-Info "[DRY-RUN] 跳过备份"
        return
    }

    if (Test-Path "$global:DSH_HOME/dsh-go") {
        Copy-Item "$global:DSH_HOME/dsh-go" -Destination $backupDir -Recurse -Force
        Write-Ok "备份完成: $backupDir"
        $backupDir | Out-File -FilePath $env:TEMP/dshgo_preset_backup_path -Encoding utf8
    }
    else {
        Write-Info "原配置不存在，无需备份"
    }
}

# ==================== 合并 UI 配置 ====================
function Merge-UiConfig {
    Write-Step "合并 UI 配置 (ui.json)"

    $presetObj = $global:PRESET_JSON | ConvertFrom-Json
    $uiJson = $presetObj.ui | ConvertTo-Json -Depth 10

    if ($DryRun) {
        Write-Info "[DRY-RUN] 将写入 ui.json:"
        $uiJson | ConvertFrom-Json | ConvertTo-Json -Depth 10
        return
    }

    New-Item -ItemType Directory -Path "$global:DSH_HOME/dsh-go" -Force | Out-Null
    $targetFile = "$global:DSH_HOME/dsh-go/ui.json"
    $existingJson = '{}'

    if (Test-Path $targetFile) {
        $existingJson = Get-Content $targetFile -Raw
        # 深度合并：预设覆盖现有
        $merged = @{} + (ConvertFrom-Json $existingJson) + (ConvertFrom-Json $uiJson)
        $uiJson = $merged | ConvertTo-Json -Depth 10
    }

    Set-Content -Path $targetFile -Value $uiJson -Encoding utf8
    Write-Ok "UI 配置已写入: $targetFile"
}

# ==================== 安装插件 ====================
function Install-Plugins {
    Write-Step "安装插件"

    $presetObj = $global:PRESET_JSON | ConvertFrom-Json
    $plugins = $presetObj.plugins | Where-Object { $_.enabled }

    if (-not $plugins) {
        Write-Info "无启用的插件"
        return
    }

    # 检查 dsh CLI
    $dshCmd = if (Get-Command dsh -ErrorAction SilentlyContinue) { 'dsh' } elseif (Get-Command dsh-go-cli -ErrorAction SilentlyContinue) { 'dsh-go-cli' } else { 'dsh' }
    Write-Warn "未找到 dsh CLI，尝试使用 $dshCmd"

    foreach ($plugin in $plugins) {
        $id = $plugin.id
        $source = $plugin.source
        $repo = $plugin.repo
        $branch = if ($plugin.branch) { $plugin.branch } else { 'main' }

        Write-Info "安装插件: $id ($source)"

        if ($DryRun) {
            Write-Info "[DRY-RUN] 将安装: $id from $source:$repo@$branch"
            continue
        }

        switch ($source) {
            'github' {
                if ($repo) {
                    & $dshCmd plugin --profile web add "github:$repo@$branch" 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warn "插件 $id 安装失败，继续下一个"
                    }
                }
                else {
                    Write-Warn "GitHub 插件缺少 repo 字段: $id"
                }
            }
            'local' {
                Write-Warn "本地插件安装需手动复制到 $global:DSH_HOME/dsh-go/plugins/$id"
            }
            'npm' {
                Write-Warn "npm 插件安装需手动运行: pnpm add -g $repo"
            }
            default {
                Write-Warn "未知插件来源: $source"
            }
        }
    }

    Write-Ok "插件安装完成"
}

# ==================== 写入模型配置 ====================
function Write-ModelConfig {
    Write-Step "写入模型接口配置"

    $presetObj = $global:PRESET_JSON | ConvertFrom-Json

    if ($DryRun) {
        Write-Info "[DRY-RUN] 可用模型接口:"
        $presetObj.modelProfiles | Select-Object id, name, provider, defaultModel | Format-Table
        return
    }

    $profiles = $presetObj.modelProfiles

    if ($ModelProfile) {
        $selected = $profiles | Where-Object { $_.id -eq $ModelProfile }
        if (-not $selected) {
            Write-Error "未找到模型接口: $ModelProfile"
            return
        }
        $profiles = $selected
    }

    $modelConfigFile = "$global:DSH_HOME/dsh-go/engines.json"
    $profiles | ConvertTo-Json -Depth 10 | Out-File -FilePath "$modelConfigFile.tmp" -Encoding utf8
    Write-Info "模型配置已生成: $modelConfigFile.tmp (需手动合并到 engines.json)"
}

# ==================== 注册自动化任务 ====================
function Register-Automations {
    Write-Step "注册自动化任务"

    $presetObj = $global:PRESET_JSON | ConvertFrom-Json
    $automations = $presetObj.automations | Where-Object { $_.enabled }

    if (-not $automations) {
        Write-Info "无启用的自动化任务"
        return
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] 将注册自动化任务:"
        $automations | ConvertTo-Json -Depth 10
        return
    }

    $autoFile = "$global:DSH_HOME/dsh-go/automations.json"
    $automations | ConvertTo-Json -Depth 10 | Out-File -FilePath $autoFile -Encoding utf8
    Write-Ok "自动化任务已写入: $autoFile"
}

# ==================== 执行 Hooks ====================
function Run-Hooks {
    param([string]$Phase)
    Write-Step "执行 $Phase hooks"

    $presetObj = $global:PRESET_JSON | ConvertFrom-Json
    $hooks = $presetObj.hooks.$Phase

    if (-not $hooks) { return }

    foreach ($hook in $hooks) {
        if (-not $hook) { continue }
        Write-Info "执行: $hook"

        if ($DryRun) {
            Write-Info "[DRY-RUN] 将执行: $hook"
            continue
        }

        try {
            Invoke-Expression $hook
        }
        catch {
            Write-Warn "Hook 执行失败: $hook"
        }
    }
}

# ==================== 重载 dsh-go ====================
function Reload-DshGo {
    Write-Step "重载 dsh-go"

    if ($DryRun) {
        Write-Info "[DRY-RUN] 将重载 dsh-go"
        return
    }

    if (Get-Command dsh -ErrorAction SilentlyContinue) {
        & dsh plugin --profile web reload 2>$null
    }
    if (Get-Command dsh-go-cli -ErrorAction SilentlyContinue) {
        & dsh-go-cli reload 2>$null
    }

    Write-Ok "重载信号已发送"
}

# ==================== 验证安装 ====================
function Verify-Install {
    Write-Step "验证安装"

    if ($DryRun) {
        Write-Info "[DRY-RUN] 跳过验证"
        return
    }

    $ok = $true

    # 检查 ui.json
    if (Test-Path "$global:DSH_HOME/dsh-go/ui.json") {
        Write-Ok "ui.json 存在"
    }
    else {
        Write-Error "ui.json 缺失"
        $ok = $false
    }

    # 检查插件目录
    if (Test-Path "$global:DSH_HOME/dsh-go/plugins") {
        $pluginCount = (Get-ChildItem "$global:DSH_HOME/dsh-go/plugins" -Directory).Count
        Write-Ok "插件目录存在 ($pluginCount 个插件)"
    }
    else {
        Write-Warn "插件目录不存在"
    }

    # 检查自动化任务
    if (Test-Path "$global:DSH_HOME/dsh-go/automations.json") {
        Write-Ok "automations.json 存在"
    }
    else {
        Write-Warn "automations.json 缺失"
    }

    if ($ok) { Write-Ok "验证通过" } else { Write-Warn "部分验证未通过，请手动检查" }
}

# ==================== 回滚函数 ====================
function Rollback {
    $backupPathFile = "$env:TEMP/dshgo_preset_backup_path"
    if (Test-Path $backupPathFile) {
        $backupPath = Get-Content $backupPathFile -Raw
        if (Test-Path $backupPath) {
            Write-Warn "回滚到备份: $backupPath"
            Remove-Item "$global:DSH_HOME/dsh-go" -Recurse -Force -ErrorAction SilentlyContinue
            Move-Item $backupPath "$global:DSH_HOME/dsh-go" -Force
            Write-Ok "回滚完成"
        }
    }
}

# ==================== 主流程 ====================
try {
    Write-Host ""
    Write-Info "=========================================="
    Write-Info "  dshgo-config-preset 一键安装脚本"
    Write-Info "  预设: $Preset"
    Write-Info "=========================================="
    Write-Host ""

    Detect-OS
    Detect-DshHome
    Check-Dependencies
    Fetch-Preset
    Confirm-Install
    Backup-Config
    Merge-UiConfig
    Install-Plugins
    Write-ModelConfig
    Register-Automations
    Run-Hooks -Phase 'preReload'
    Reload-DshGo
    Run-Hooks -Phase 'postReload'
    Verify-Install

    Write-Host ""
    Write-Ok "=========================================="
    Write-Ok "  安装完成！"
    Write-Ok "=========================================="
    Write-Host ""
    Write-Info "后续步骤:"
    Write-Info "  1. 重启 dsh-go App 查看效果"
    Write-Info "  2. 在设置中配置模型 API Key (引用 DSH_SECRET_*)"
    Write-Info "  3. 如需回滚: Move-Item $global:DSH_HOME/dsh-go.bak.* $global:DSH_HOME/dsh-go -Force"
    Write-Host ""
}
catch {
    Write-Error "安装失败: $($_.Exception.Message)"
    Rollback
    exit 1
}