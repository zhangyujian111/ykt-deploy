#!/usr/bin/env bash
# ykt-deploy 一键部署脚本
#
# 流程：
#   1. 校验前置依赖（docker / docker compose）
#   2. 加载 .env 环境变量
#   3. 用 envsubst 渲染 configs/*.yaml 中的占位符（${VAR}）
#   4. 首次启动时把 migrations/ 复制到 ./migrations/init/
#   5. docker compose pull + up -d
#
# 使用：
#   cp .env.example .env   # 填入实际值
#   ./deploy.sh            # 启动
#   ./deploy.sh logs       # 查看日志
#   ./deploy.sh down       # 停止
#   ./deploy.sh restart    # 重启

set -euo pipefail

# ============== 路径 ==============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ============== 颜色输出 ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[deploy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
err()   { echo -e "${RED}[error]${NC} $*" >&2; }

# ============== 1. 前置检查 ==============
check_deps() {
  command -v docker >/dev/null 2>&1 || { err "docker 未安装"; exit 1; }
  docker compose version >/dev/null 2>&1 || { err "docker compose plugin 未安装"; exit 1; }
  command -v envsubst >/dev/null 2>&1 || { err "envsubst 未安装（apt-get install gettext-base）"; exit 1; }
}

# ============== 2. 加载 .env ==============
load_env() {
  if [ ! -f .env ]; then
    err ".env 不存在；先 cp .env.example .env 并填好变量"
    exit 1
  fi
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
  log "环境变量已加载"
}

# ============== 3. 渲染 configs/*.yaml 中的占位符 ==============
render_configs() {
  log "渲染生产配置..."
  local count=0
  for src in $(find configs -name "*.yaml"); do
    dst="${src%.yaml}.rendered.yaml"
    envsubst < "$src" > "$dst"
    chmod 600 "$dst"
    count=$((count + 1))
  done
  log "渲染完成 $count 个配置文件"
}

# ============== 4. 准备 mysql init 目录 ==============
prepare_init_sql() {
  mkdir -p migrations/init
  # 若 init 目录为空，提示用户先迁移 SQL
  if [ -z "$(ls -A migrations/init 2>/dev/null)" ]; then
    warn "migrations/init/ 为空；首次部署需把以下 SQL 文件放到该目录："
    warn "  - ykt-aisaas/migrations/000001_init.up.sql ~ 000022_ai_traces.up.sql"
    warn "  - ykt-aisaas/migrations/900001__ykt_sys_tenant.sql"
    warn "MySQL 首次启动时只读取 /docker-entrypoint-initdb.d/，之后不会再执行。"
  fi
}

# ============== 5. 替换 docker-compose 中指向 rendered configs 的挂载 ==============
# 已通过 envsubst 渲染到 configs/*.rendered.yaml；
# 但 docker-compose.yml 仍写的是 config.yaml，因此这里把渲染结果覆盖到原路径。
override_mounts() {
  for f in configs/xiaozhi-server-go/config.yaml \
           configs/ykt-admin-go/config.yaml \
           configs/ykt-aisaas/config.yaml; do
    if [ -f "${f%.yaml}.rendered.yaml" ]; then
      cp "${f%.yaml}.rendered.yaml" "$f"
    fi
  done
}

# ============== 6. ACR 登录 ==============
acr_login() {
  log "登录阿里云 ACR ${ALIYUN_ACR_REGISTRY}..."
  echo "$ALIYUN_ACR_PASSWORD" | docker login \
    --username "$ALIYUN_ACR_USERNAME" \
    --password-stdin "$ALIYUN_ACR_REGISTRY"
}

# ============== 7. 拉取镜像并启动 ==============
up() {
  acr_login
  log "拉取镜像..."
  docker compose pull
  log "启动服务..."
  docker compose up -d --remove-orphans
  log "部署完成"
  docker compose ps
}

down() {
  docker compose down
}

restart() {
  docker compose restart
}

logs() {
  docker compose logs -f --tail=200 "${@}"
}

case "${1:-up}" in
  up)       check_deps; load_env; render_configs; override_mounts; prepare_init_sql; up ;;
  down)     down ;;
  restart)  restart ;;
  logs)     shift; logs "$@" ;;
  render)   check_deps; load_env; render_configs; override_mounts ;;
  *)        err "未知命令: $1"; echo "用法: $0 {up|down|restart|logs|render}"; exit 1 ;;
esac
