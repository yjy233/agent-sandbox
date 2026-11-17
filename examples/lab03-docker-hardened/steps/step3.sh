#!/usr/bin/env bash
# Step 3: 资源限制 —— pids-limit 防 fork 炸弹、tmpfs+memory 防磁盘/内存耗尽
set -u
LAB_DIR=$(cd "$(dirname "$0")/.." && pwd)
source "$LAB_DIR/../lib/assert.sh"
require_cmd docker

IMG=alpine:3.20

echo "== Step 3: 资源限制 =="

# pids-limit 8：尝试 fork 10 个后台进程，必然有失败
expect_output "pids-limit 触发 fork 失败" "fork" \
  docker run --rm --pids-limit 8 "$IMG" \
  sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do sleep 30 & done; wait'

# tmpfs 32m：写 100m 必然 ENOSPC
expect_fail "tmpfs 限额阻止大文件写入" \
  docker run --rm --read-only --tmpfs /tmp:size=32m "$IMG" \
  sh -c 'head -c 100m /dev/zero > /tmp/big'

finish