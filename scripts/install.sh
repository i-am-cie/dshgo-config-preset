#!/usr/bin/env bash
# dshgo-config-preset 一键安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/i-am-cie/dshgo-config-preset/main/scripts/install.sh | bash
#   或: bash install.sh [--preset default|minimal|dev] [--model-profile <id>] [--dry-run] [--yes]

set -euo pipefail

# ==================== 配置常量 ====================
REPO_OWNER="i-am-cie"
REPO_NAME="dshgo-config-preset"
REPO_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"

# 预设文件映射
declare -A PRESET_FILES=(
  ["default"]="presets/default.json"
  ["minimal"]="presets/minimal.json"
  ["dev"]="presets/dev.json"
)

# 默认值
PRESET="default"
MODEL_PROFILE=""
DRY_RUN=false
ASSUME_YES=false
FORCE=false

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $*"; }

# ==================== 帮助信息 ====================
usage() {
  cat <<EOF
用法: $0 [选项]

选项:
  --preset <name>       选择预设: default | minimal | dev (默认: default)
  --model-profile <id>  预选模型接口配置 (跳过交互)
  --dry-run             仅模拟运行，不写入文件
  --yes, -y             自动确认所有提示
  --force               强制覆盖，不备份原配置
  --help, -h            显示帮助

示例:
  $0 --preset dev --yes
  $0 --preset minimal --model-profile ollama-local
EOF
}

# ==================== 参数解析 ====================
while [[ $# -gt 0 ]]; do
  case $1 in
    --preset)
      PRESET="${2:-}"
      shift 2
      ;;
    --model-profile)
      MODEL_PROFILE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --yes|-y)
      ASSUME_YES=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      log_error "未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

# ==================== 预设验证 ====================
if [[ ! ${PRESET_FILES[$PRESET]+_} ]]; then
  log_error "无效预设: $PRESET (可选: ${!PRESET_FILES[@]})"
  exit 1
fi

PRESET_FILE="${PRESET_FILES[$PRESET]}"

# ==================== 环境检测 ====================
detect_os() {
  case "$(uname -s)" in
    Linux*)     OS="linux" ;;
    Darwin*)    OS="macos" ;;
    CYGWIN*|MINGW*|MSYS*) OS="windows" ;;
    *)          OS="unknown" ;;
  esac

  # Termux (Android) 检测
  if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]; then
    OS="termux"
  fi

  log_info "检测到操作系统: $OS"
}

detect_dsh_home() {
  if [[ -n "${DSH_HOME:-}" && -d "$DSH_HOME" ]]; then
    DSH_HOME="$DSH_HOME"
  elif [[ -d "$HOME/.dsh" ]]; then
    DSH_HOME="$HOME/.dsh"
  elif [[ -d "/opt/dsh" ]]; then
    DSH_HOME="/opt/dsh"
  else
    DSH_HOME="$HOME/.dsh"
    log_warn "未找到 DSH_HOME，使用默认: $DSH_HOME"
  fi

  if [[ ! -d "$DSH_HOME/dsh-go" ]]; then
    log_warn "dsh-go 目录不存在: $DSH_HOME/dsh-go (安装脚本将创建)"
  fi

  log_info "DSH_HOME: $DSH_HOME"
}

check_dependencies() {
  local missing=()
  local cmd

  for cmd in curl git jq bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  # Python3 可选（用于某些插件）
  if ! command -v python3 >/dev/null 2>&1; then
    log_warn "未找到 python3，部分插件可能无法安装"
  fi

  # Node.js/pnpm 可选（用于 npm 源插件）
  if ! command -v node >/dev/null 2>&1; then
    log_warn "未找到 Node.js，npm 源插件将跳过"
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "缺少必要工具: ${missing[*]}"
    log_error "请先安装后再运行此脚本"
    exit 1
  fi

  log_ok "依赖检查通过"
}

# ==================== 下载预设 ====================
fetch_preset() {
  local url="${RAW_BASE}/${PRESET_FILE}"
  log_step "下载预设: $url"

  if $DRY_RUN; then
    log_info "[DRY-RUN] 跳过下载"
    return 0
  fi

  if ! PRESET_JSON=$(curl -fsSL "$url"); then
    log_error "下载预设失败: $url"
    exit 1
  fi

  # 校验 JSON 语法
  if ! echo "$PRESET_JSON" | jq empty 2>/dev/null; then
    log_error "预设 JSON 语法错误"
    exit 1
  fi

  log_ok "预设下载并校验通过"
}

# ==================== 交互式确认 ====================
confirm_install() {
  if $ASSUME_YES; then
    return 0
  fi

  echo
  log_info "即将应用预设: ${CYAN}$PRESET${NC}"
  log_info "目标目录: ${CYAN}$DSH_HOME/dsh-go${NC}"
  echo

  # 显示预设摘要
  local plugin_count model_count
  plugin_count=$(echo "$PRESET_JSON" | jq '.plugins | length')
  model_count=$(echo "$PRESET_JSON" | jq '.modelProfiles | length')
  log_info "包含插件: $plugin_count 个"
  log_info "模型接口: $model_count 个"

  if [[ -n "$MODEL_PROFILE" ]]; then
    log_info "预选模型: $MODEL_PROFILE"
  fi

  echo
  read -rp "确认继续? [y/N] " -n 1 REPLY
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || { log_info "已取消"; exit 0; }
}

# ==================== 备份原配置 ====================
backup_config() {
  if $FORCE; then
    log_warn "--force 模式，跳过备份"
    return 0
  fi

  local backup_dir="${DSH_HOME}/dsh-go.bak.$(date +%s)"
  log_step "备份原配置到: $backup_dir"

  if $DRY_RUN; then
    log_info "[DRY-RUN] 跳过备份"
    return 0
  fi

  if [[ -d "$DSH_HOME/dsh-go" ]]; then
    cp -r "$DSH_HOME/dsh-go" "$backup_dir"
    log_ok "备份完成: $backup_dir"
    echo "$backup_dir" > /tmp/dshgo_preset_backup_path
  else
    log_info "原配置不存在，无需备份"
  fi
}

# ==================== 合并 UI 配置 ====================
merge_ui_config() {
  log_step "合并 UI 配置 (ui.json)"

  local ui_json
  ui_json=$(echo "$PRESET_JSON" | jq '.ui')

  if $DRY_RUN; then
    log_info "[DRY-RUN] 将写入 ui.json:"
    echo "$ui_json" | jq .
    return 0
  fi

  mkdir -p "$DSH_HOME/dsh-go"

  local target_file="$DSH_HOME/dsh-go/ui.json"
  local existing_json="{}"

  if [[ -f "$target_file" ]]; then
    existing_json=$(cat "$target_file")
    # 深度合并：预设覆盖现有，但保留用户自定义的未在预设中的字段
    ui_json=$(jq -n --argjson preset "$ui_json" --argjson existing "$existing_json" '
      $existing * $preset
    ')
  fi

  echo "$ui_json" | jq . > "$target_file"
  log_ok "UI 配置已写入: $target_file"
}

# ==================== 安装插件 ====================
install_plugins() {
  log_step "安装插件"

  local plugins
  plugins=$(echo "$PRESET_JSON" | jq -c '.plugins[] | select(.enabled == true)')

  if [[ -z "$plugins" ]]; then
    log_info "无启用的插件"
    return 0
  fi

  # 检查 dsh CLI
  if ! command -v dsh >/dev/null 2>&1; then
    log_warn "未找到 dsh CLI，尝试使用 dsh-go-cli 或直接复制"
    DSH_CMD="dsh-go-cli"
  else
    DSH_CMD="dsh"
  fi

  while IFS= read -r plugin; do
    local id source repo branch enabled
    id=$(echo "$plugin" | jq -r '.id')
    source=$(echo "$plugin" | jq -r '.source')
    repo=$(echo "$plugin" | jq -r '.repo // ""')
    branch=$(echo "$plugin" | jq -r '.branch // "main"')
    enabled=$(echo "$plugin" | jq -r '.enabled')

    if [[ "$enabled" != "true" ]]; then
      continue
    fi

    log_info "安装插件: $id ($source)"

    if $DRY_RUN; then
      log_info "[DRY-RUN] 将安装: $id from $source:$repo@$branch"
      continue
    fi

    case "$source" in
      github)
        if [[ -n "$repo" ]]; then
          $DSH_CMD plugin --profile web add "github:$repo@$branch" || {
            log_warn "插件 $id 安装失败，继续下一个"
          }
        else
          log_warn "GitHub 插件缺少 repo 字段: $id"
        fi
        ;;
      local)
        log_warn "本地插件安装需手动复制到 $DSH_HOME/dsh-go/plugins/$id"
        ;;
      npm)
        log_warn "npm 插件安装需手动运行: pnpm add -g $repo"
        ;;
      *)
        log_warn "未知插件来源: $source"
        ;;
    esac
  done <<< "$plugins"

  log_ok "插件安装完成"
}

# ==================== 写入模型配置 ====================
write_model_config() {
  log_step "写入模型接口配置"

  local profiles
  profiles=$(echo "$PRESET_JSON" | jq -c '.modelProfiles[]')

  if $DRY_RUN; then
    log_info "[DRY-RUN] 可用模型接口:"
    echo "$PRESET_JSON" | jq '.modelProfiles[] | {id, name, provider, defaultModel}'
    return 0
  fi

  # 如果用户指定了模型，只写入该配置
  if [[ -n "$MODEL_PROFILE" ]]; then
    local selected
    selected=$(echo "$PRESET_JSON" | jq -c --arg id "$MODEL_PROFILE" '.modelProfiles[] | select(.id == $id)')
    if [[ -z "$selected" ]]; then
      log_error "未找到模型接口: $MODEL_PROFILE"
      return 1
    fi
    profiles="$selected"
  fi

  # 这里需要根据 dsh-go 实际配置文件格式写入
  # 暂时输出到临时文件供参考
  local model_config_file="$DSH_HOME/dsh-go/engines.json"
  echo "$profiles" | jq -s '.' > "$model_config_file.tmp"
  log_info "模型配置已生成: $model_config_file.tmp (需手动合并到 engines.json)"
}

# ==================== 注册自动化任务 ====================
register_automations() {
  log_step "注册自动化任务"

  local automations
  automations=$(echo "$PRESET_JSON" | jq -c '.automations[] | select(.enabled == true)')

  if [[ -z "$automations" ]]; then
    log_info "无启用的自动化任务"
    return 0
  fi

  if $DRY_RUN; then
    log_info "[DRY-RUN] 将注册自动化任务:"
    echo "$automations" | jq .
    return 0
  fi

  local auto_file="$DSH_HOME/dsh-go/automations.json"
  echo "$automations" | jq -s '.' > "$auto_file"
  log_ok "自动化任务已写入: $auto_file"
}

# ==================== 执行 Hooks ====================
run_hooks() {
  local phase=$1
  log_step "执行 $phase hooks"

  local hooks
  hooks=$(echo "$PRESET_JSON" | jq -r ".hooks.$phase[]?" 2>/dev/null || true)

  if [[ -z "$hooks" ]]; then
    return 0
  fi

  while IFS= read -r hook; do
    [[ -z "$hook" ]] && continue
    log_info "执行: $hook"

    if $DRY_RUN; then
      log_info "[DRY-RUN] 将执行: $hook"
      continue
    fi

    eval "$hook" || log_warn "Hook 执行失败: $hook"
  done <<< "$hooks"
}

# ==================== 重载 dsh-go ====================
reload_dsh_go() {
  log_step "重载 dsh-go"

  if $DRY_RUN; then
    log_info "[DRY-RUN] 将重载 dsh-go"
    return 0
  fi

  # 尝试多种重载方式
  if command -v dsh >/dev/null 2>&1; then
    dsh plugin --profile web reload || true
  fi

  if command -v dsh-go-cli >/dev/null 2>&1; then
    dsh-go-cli reload || true
  fi

  # 发送信号给运行中的进程（如果有）
  pkill -f "dsh-go" -USR1 2>/dev/null || true

  log_ok "重载信号已发送"
}

# ==================== 验证安装 ====================
verify_install() {
  log_step "验证安装"

  if $DRY_RUN; then
    log_info "[DRY-RUN] 跳过验证"
    return 0
  fi

  local ok=true

  # 检查 ui.json
  if [[ -f "$DSH_HOME/dsh-go/ui.json" ]]; then
    log_ok "ui.json 存在"
  else
    log_error "ui.json 缺失"
    ok=false
  fi

  # 检查插件目录
  if [[ -d "$DSH_HOME/dsh-go/plugins" ]]; then
    local plugin_count
    plugin_count=$(find "$DSH_HOME/dsh-go/plugins" -maxdepth 1 -type d | wc -l)
    plugin_count=$((plugin_count - 1))
    log_ok "插件目录存在 ($plugin_count 个插件)"
  else
    log_warn "插件目录不存在"
  fi

  # 检查自动化任务
  if [[ -f "$DSH_HOME/dsh-go/automations.json" ]]; then
    log_ok "automations.json 存在"
  else
    log_warn "automations.json 缺失"
  fi

  $ok && log_ok "验证通过" || log_warn "部分验证未通过，请手动检查"
}

# ==================== 回滚函数 ====================
rollback() {
  local backup_path
  if [[ -f /tmp/dshgo_preset_backup_path ]]; then
    backup_path=$(cat /tmp/dshgo_preset_backup_path)
    if [[ -d "$backup_path" ]]; then
      log_warn "回滚到备份: $backup_path"
      rm -rf "$DSH_HOME/dsh-go"
      mv "$backup_path" "$DSH_HOME/dsh-go"
      log_ok "回滚完成"
    fi
  fi
}

# ==================== 主流程 ====================
main() {
  echo
  log_info "=========================================="
  log_info "  dshgo-config-preset 一键安装脚本"
  log_info "  预设: $PRESET"
  log_info "=========================================="
  echo

  # 错误时自动回滚
  trap 'log_error "安装失败，正在回滚..."; rollback; exit 1' ERR

  detect_os
  detect_dsh_home
  check_dependencies
  fetch_preset
  confirm_install
  backup_config
  merge_ui_config
  install_plugins
  write_model_config
  register_automations
  run_hooks "preReload"
  reload_dsh_go
  run_hooks "postReload"
  verify_install

  echo
  log_ok "=========================================="
  log_ok "  安装完成！"
  log_ok "=========================================="
  echo
  log_info "后续步骤:"
  log_info "  1. 重启 dsh-go App 查看效果"
  log_info "  2. 在设置中配置模型 API Key (引用 DSH_SECRET_*)"
  log_info "  3. 如需回滚: mv $DSH_HOME/dsh-go.bak.* $DSH_HOME/dsh-go"
  echo
}

main "$@"