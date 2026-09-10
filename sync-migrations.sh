#!/usr/bin/env bash
# 把 ykt-aisaas 的 migrations 同步到 ykt-deploy 的 init 目录。
#
# 设计原因：
#   - MySQL 仅在空数据卷首次启动时执行 /docker-entrypoint-initdb.d/。
#   - 上游 migrations 由 ykt-aisaas 仓库维护；本脚本维护一份拷贝（带前缀排序）。
#   - 后续 schema 变更走 golang-migrate，不走 init。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SRC:-$SCRIPT_DIR/../ykt-aisaas/migrations}"
DST="${DST:-$SCRIPT_DIR/migrations/init}"

if [ ! -d "$SRC" ]; then
  echo "[error] 源目录不存在: $SRC"
  exit 1
fi

mkdir -p "$DST"

# 复制所有 .up.sql（init 目录只放正向脚本，不放 .down.sql）
copied=0
for f in "$SRC"/*.up.sql "$SRC"/900001__ykt_sys_tenant.sql; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  cp -f "$f" "$DST/$base"
  copied=$((copied + 1))
done

echo "[sync] 复制了 $copied 个 SQL 文件到 $DST"
